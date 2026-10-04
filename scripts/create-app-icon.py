#!/usr/bin/env python3
"""Regenerate Flow artwork using Xcode Icon Composer, AppKit and Pillow.

Normal app builds compile the checked-in AppIcon.icon directly; this script is
only needed when the approved Figma vector changes. No hand-drawn icon mask.
"""
import json
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET

from PIL import Image, ImageCms

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT / 'HTools/Resources/AppIcon.icon'
ASSETS = ROOT / 'HTools/Resources/Assets.xcassets'

# The exact Figma export is retained. Only split off its background rectangle;
# all foreground path coordinates, curves and the six-degree lean stay intact.
ET.register_namespace('', 'http://www.w3.org/2000/svg')
svg = ET.fromstring((ROOT / 'assets/htools-flow-figma.svg').read_text())
backgrounds = svg.findall('{http://www.w3.org/2000/svg}rect')
if len(backgrounds) != 1 or backgrounds[0].get('fill') != '#25272B':
    raise ValueError('Expected the approved Flow export with a single charcoal background')
svg.remove(backgrounds[0])
(ICON / 'Assets').mkdir(parents=True, exist_ok=True)
layer = ICON / 'Assets/flow.svg'
layer.write_text(ET.tostring(svg, encoding='unicode') + '\n')

# Use Apple's actual platform renderer for the README preview. Xcode generates
# the installed icon, appearance variants and legacy .icns from AppIcon.icon.
developer = Path(subprocess.check_output(['xcode-select', '-p'], text=True).strip())
ictool = developer.parent / 'Applications/Icon Composer.app/Contents/Executables/ictool'
subprocess.run([str(ictool), str(ICON), '--export-image', '--output-file',
                str(ROOT / 'assets/app-icon.png'), '--platform', 'macOS',
                '--rendition', 'Default', '--width', '1024', '--height', '1024',
                '--scale', '1'], check=True)

# A status-item template has no tile, color or baked-in shadow. Fill the 18 pt
# slot with a 16 pt mark and one point of breathing room on every side.
menu = ASSETS / 'MenuBarIcon.imageset'
menu.mkdir(parents=True, exist_ok=True)
profile = ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
with tempfile.TemporaryDirectory(prefix='htools-icon-') as temporary:
    raster = Path(temporary) / 'foreground.png'
    subprocess.run(['xcrun', 'swift', str(ROOT / 'scripts/rasterize-icon.swift'),
                    str(layer), str(raster)], check=True)
    alpha = Image.open(raster).convert('RGBA').getchannel('A')
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError('Empty foreground SVG')
    alpha = alpha.crop(bounds)
    images = []
    for density in (1, 2):
        coverage = alpha.copy()
        coverage.thumbnail((16 * density, 16 * density), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (18 * density, 18 * density), (0, 0, 0, 0))
        glyph = Image.new('RGBA', coverage.size, (0, 0, 0, 0))
        glyph.putalpha(coverage)
        canvas.paste(glyph, ((canvas.width - glyph.width) // 2,
                            (canvas.height - glyph.height) // 2))
        filename = f'menu-bar-icon@{density}x.png'
        canvas.save(menu / filename, icc_profile=profile)
        images.append({'filename': filename, 'idiom': 'mac', 'scale': f'{density}x'})
(menu / 'Contents.json').write_text(json.dumps({
    'images': images, 'info': {'version': 1, 'author': 'xcode'},
    'properties': {'template-rendering-intent': 'template'},
}, indent=2) + '\n')
print('Generated Flow layer, Apple-rendered preview and 1x/2x menu templates.')
