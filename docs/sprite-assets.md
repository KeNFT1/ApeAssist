# Lulo Sprite Assets

The checked-in source sheet is:

```text
Resources/Sprites/lulo-sprite-sheet.png
Resources/Sprites/lulo-sprite-sheet.json
```

Keep that PNG intact for provenance. It is the current 4×4, 1024×1024 sheet generated from the Lulo reference on a chroma background, then chroma-keyed locally to alpha.

## Local pipeline

All asset work is local and stdlib-only:

```bash
# Inspect the source sheet and frame bounds/alpha quality
scripts/sprite_pipeline.py inspect

# Slice 16 deterministic PNG frames into Resources/Sprites/Frames/
scripts/sprite_pipeline.py slice

# Create Resources/AppIcon/LuloAppIcon.png/.iconset/.icns from frame 4
scripts/sprite_pipeline.py icon

# Do all of the above
scripts/sprite_pipeline.py all
```

`LuloSpriteView` now prefers the pre-sliced `Resources/Sprites/Frames/lulo-00.png` … `lulo-15.png` files, falling back to runtime sheet cropping if those files are absent. This avoids recropping during animation and keeps the original sheet as backup/provenance.

## Current inspection notes

Latest local inspection of the source sheet:

- Sheet: 1024×1024 RGBA
- Grid: 4×4, 256×256 per frame
- Alpha: present; 741,600 fully transparent pixels, 306,953 fully opaque pixels, only 23 semi-transparent pixels
- Some frames touch a cell edge (`6`, `7`, `8`, `10`, `11`, `12`, `14`, `15`), so future generations should leave more padding if possible.

The tiny count of semi-transparent pixels means the chroma-keyed edges are mostly hard. If the sprite looks jagged at larger sizes, regenerate/key with a soft matte or add an alpha-feathering pass before slicing.

## Chroma-keying a replacement source

If you have a local replacement PNG on a green/chroma background:

```bash
scripts/sprite_pipeline.py chroma-key path/to/source.png Resources/Sprites/lulo-sprite-sheet.png \
  --key 00ff00 \
  --tolerance 42 \
  --feather 24
scripts/sprite_pipeline.py all
```

Adjust `--key`, `--tolerance`, and `--feather` based on the actual background color. Do not call image APIs from this pipeline.

## App icon / packaging

The app icon is derived from frame `4` (the first wave frame):

```text
Resources/AppIcon/LuloAppIcon.png
Resources/AppIcon/LuloAppIcon.iconset/
Resources/AppIcon/LuloAppIcon.icns
```

Package a local `.app` bundle with the generated icon:

```bash
scripts/package-app.sh
open dist/Lulo\ Clippy.app
```

The package script builds the SwiftPM executable, copies SwiftPM resource bundles, installs `LuloAppIcon.icns`, and writes `CFBundleIconFile` in `Info.plist`.
