# Fastlane Metadata Directory

This directory contains metadata and assets for Google Play Store uploads.

## Directory Structure

```
fastlane/metadata/android/
└── de-DE/                    # German locale
    ├── title.txt             # App name
    ├── short_description.txt # Short description (80 chars max)
    ├── full_description.txt  # Full description (4000 chars max)
    └── images/
        ├── featureGraphic.svg       # Feature graphic source (vector)
        ├── featureGraphic.png      # Feature graphic (1024x500px)
        ├── icon.svg                # App icon source (vector)
        ├── icon.png                # App icon (512x512px)
        ├── convert-svg-to-png.sh   # Script to regenerate PNGs from SVGs
        ├── phoneScreenshots/       # Phone screenshots (2-8 images)
        ├── sevenInchScreenshots/    # 7-inch tablet screenshots
        └── tenInchScreenshots/     # 10-inch tablet screenshots
```

## Required Assets

### App Icon (`icon.png`)
- **Size:** 512x512px
- **Format:** PNG or JPEG
- **Max size:** 1 MB
- **Required:** Yes

### Feature Graphic (`featureGraphic.png`)
- **Size:** 1024x500px
- **Format:** PNG or JPEG
- **Max size:** 15 MB
- **Required:** Yes

### Phone Screenshots (`phoneScreenshots/`)
- **Count:** 2-8 screenshots
- **Aspect ratio:** 16:9 or 9:16
- **Size:** 320-3840px per side
- **Format:** PNG or JPEG
- **Max size:** 8 MB each
- **Required:** Yes

### Tablet Screenshots
- **7-inch:** `sevenInchScreenshots/` (320-3840px)
- **10-inch:** `tenInchScreenshots/` (1080-7680px)
- **Format:** PNG or JPEG
- **Max size:** 8 MB each
- **Required:** Yes

## Usage

Once you've added your assets to the appropriate folders, Fastlane will automatically upload them when you run:

```bash
cd android
fastlane release  # or internal, alpha, beta
```

The `skip_upload_images` and `skip_upload_screenshots` flags in the Fastfile will need to be set to `false` (or removed) to enable automatic uploads.

## Vector Graphics (SVG)

The app icon and feature graphic are provided as SVG files for easy editing:
- `icon.svg` - Edit this file, then run `./convert-svg-to-png.sh` to regenerate `icon.png`
- `featureGraphic.svg` - Edit this file, then run `./convert-svg-to-png.sh` to regenerate `featureGraphic.png`

To regenerate PNG files from SVG sources:
```bash
cd android/fastlane/metadata/android/de-DE/images
./convert-svg-to-png.sh
```

**Requirements:** ImageMagick (install via `brew install imagemagick`)

## Generating Screenshots

You can generate screenshots using:
- Flutter's screenshot tool: `flutter screenshot`
- Android Studio's Layout Inspector
- Physical devices or emulators
- Screenshot automation tools

## Notes

- Screenshot filenames should be unique and will appear in alphanumerical order
- Uploading new images will replace existing ones on Play Store
- All text files should be UTF-8 encoded

