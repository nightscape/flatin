# Fastlane Metadata

Metadata for F-Droid / IzzyOnDroid and Google Play Store.

F-Droid and IzzyOnDroid pick Fastlane metadata from the same tag/commit they build the app from, so changelogs must exist before creating release tags.

## Directory Structure

```
fastlane/metadata/android/
├── en-US/                        # English (required fallback for F-Droid)
│   ├── title.txt                 # App name
│   ├── short_description.txt     # Max 80 chars
│   ├── full_description.txt      # Max 4000 chars
│   ├── changelogs/
│   │   └── <versionCode>.txt     # Max 500 bytes, plain ASCII
│   └── images/
│       ├── icon.png              # 512x512px
│       ├── featureGraphic.png    # 1024x500px
│       └── phoneScreenshots/     # PNG/JPG, height:width ratio max 2:1
├── de-DE/                        # German
│   ├── title.txt
│   ├── short_description.txt
│   ├── full_description.txt
│   ├── changelogs/
│   │   └── <versionCode>.txt
│   └── images/
│       ├── icon.png
│       ├── icon.svg              # Source vector
│       ├── featureGraphic.png
│       ├── featureGraphic.svg    # Source vector
│       ├── convert-svg-to-png.sh
│       └── phoneScreenshots/
```

## Changelogs

Changelog files are named by versionCode (from `pubspec.yaml` version string after `+`). For version `1.0.0+3`, the file is `changelogs/3.txt`. Max 500 bytes, plain ASCII only (no umlauts — use ae/oe/ue).

## Regenerating PNGs from SVGs

```bash
cd android/fastlane/metadata/android/de-DE/images
./convert-svg-to-png.sh
```

Requires ImageMagick (`brew install imagemagick`).

## Adding Screenshots

Place numbered PNG/JPG files in `phoneScreenshots/` (e.g., `1.png`, `2.png`). F-Droid downsizes to 350px on the short side. Keep height:width ratio under 2:1.
