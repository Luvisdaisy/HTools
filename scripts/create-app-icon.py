#!/usr/bin/env python3
"""Export the approved artwork as macOS app icons. Requires Pillow."""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
source = Image.open(ROOT / 'assets/app-icon-source.png').convert('RGBA')
if source.size != (1254, 1254):
    raise ValueError('The background mask is specific to the approved 1254px artwork.')

# Follow the blue tile boundary and discard the white canvas and baked shadow.
# Supersampling keeps the transparent silhouette smooth at every output size.
scale = 4
mask = Image.new('L', (1254 * scale, 1254 * scale))
ImageDraw.Draw(mask).rounded_rectangle(
    tuple(v * scale for v in (123, 123, 1132, 1126)),
    radius=245 * scale, fill=255,
)
source.putalpha(mask.resize(source.size, Image.Resampling.LANCZOS))
master = source.resize((1024, 1024), Image.Resampling.LANCZOS)
master.save(ROOT / 'assets/app-icon.png')

catalog = ROOT / 'finder-fixer/Resources/Assets.xcassets'
iconset = catalog / 'AppIcon.appiconset'
iconset.mkdir(parents=True, exist_ok=True)
info = {'version': 1, 'author': 'xcode'}
(catalog / 'Contents.json').write_text(json.dumps({'info': info}, indent=2) + '\n')
images = []
for size in (16, 32, 128, 256, 512):
    for density in (1, 2):
        pixels = size * density
        filename = f'icon_{size}x{size}' + ('@2x' if density == 2 else '') + '.png'
        master.resize((pixels, pixels), Image.Resampling.LANCZOS).save(iconset / filename)
        images.append({'filename': filename, 'idiom': 'mac',
                       'scale': f'{density}x', 'size': f'{size}x{size}'})
(iconset / 'Contents.json').write_text(
    json.dumps({'images': images, 'info': info}, indent=2) + '\n'
)
# Menu bar artwork is a separate, full-color image asset. Remove the master
# canvas padding so its symbol remains legible within the 18pt status button.
menu_set = catalog / 'MenuBarIcon.imageset'
menu_set.mkdir(parents=True, exist_ok=True)
menu_source = source.crop((123, 123, 1133, 1127))
menu_images = []
for density in (1, 2):
    filename = f'menu-bar-icon@{density}x.png'
    menu_source.resize((18 * density, 18 * density), Image.Resampling.LANCZOS).save(menu_set / filename)
    menu_images.append({'filename': filename, 'idiom': 'mac', 'scale': f'{density}x'})
(menu_set / 'Contents.json').write_text(json.dumps({
    'images': menu_images, 'info': info,
    'properties': {'template-rendering-intent': 'original'},
}, indent=2) + '\n')
print(f'Exported master, {len(images)} macOS icon representations, and menu bar artwork.')
