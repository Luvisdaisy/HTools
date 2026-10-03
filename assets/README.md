# Artwork

- `app-icon-source.png`: AI-generated source artwork from the initial project, with no embedded personal desktop content.
- `app-icon.png`: processed 1024 px master with a transparent background.
- Runtime assets are checked into `HTools/Resources/Assets.xcassets/`.

The project makes its artwork available under the repository MIT license to the extent applicable. Apple trademarks are not licensed by this project; no affiliation or endorsement is implied.

Normal app builds require no image tools. To regenerate the icon resources, install Pillow in a development virtual environment and run:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install 'Pillow>=10,<13'
.venv/bin/python scripts/create-app-icon.py
```

The background mask is specific to the included 1254 × 1254 source image. Replacing the source requires reviewing that mask and the resulting icons. This script overwrites the master and asset catalog images.

HTools v0.2.0 uses a system template symbol in the menu bar for light/dark contrast. The generated MenuBarIcon asset remains available as source artwork but is no longer used at runtime.
