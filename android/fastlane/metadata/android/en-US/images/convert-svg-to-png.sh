#!/bin/bash
# Convert SVG files to PNG for Google Play Store

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check for SVG conversion tools (prefer rsvg-convert for better SVG rendering)
if command -v rsvg-convert &> /dev/null; then
    CONVERTER="rsvg"
    echo "Using rsvg-convert (librsvg) for high-quality SVG rendering..."
elif command -v magick &> /dev/null; then
    CONVERTER="magick"
    echo "Using ImageMagick (magick) for SVG conversion..."
elif command -v convert &> /dev/null; then
    CONVERTER="convert"
    echo "Using ImageMagick (convert) for SVG conversion..."
    echo "  ⚠ Warning: ImageMagick may not render SVG text/gradients correctly."
    echo "  Consider installing librsvg: brew install librsvg"
else
    echo "Error: No SVG conversion tool found."
    echo "Install one of:"
    echo "  - librsvg (recommended): brew install librsvg"
    echo "  - ImageMagick: brew install imagemagick"
    exit 1
fi

echo "Converting SVG files to PNG..."

# Convert icon.svg to icon.png (512x512)
if [ -f "icon.svg" ]; then
    echo "  Converting icon.svg -> icon.png (512x512)..."
    if [ "$CONVERTER" = "rsvg" ]; then
        rsvg-convert --width=512 --height=512 icon.svg -o icon.png
    elif [ "$CONVERTER" = "magick" ]; then
        magick -background none -density 300 icon.svg -resize 512x512 icon.png
    else
        convert -background none -density 300 icon.svg -resize 512x512 icon.png
    fi
    echo "  ✓ Created icon.png"
else
    echo "  ⚠ icon.svg not found, skipping..."
fi

# Convert featureGraphic.svg to featureGraphic.png (1024x500)
if [ -f "featureGraphic.svg" ]; then
    echo "  Converting featureGraphic.svg -> featureGraphic.png (1024x500)..."
    if [ "$CONVERTER" = "rsvg" ]; then
        rsvg-convert --width=1024 --height=500 featureGraphic.svg -o featureGraphic.png
    elif [ "$CONVERTER" = "magick" ]; then
        magick -background none -density 300 featureGraphic.svg -resize 1024x500 featureGraphic.png
    else
        convert -background none -density 300 featureGraphic.svg -resize 1024x500 featureGraphic.png
    fi
    echo "  ✓ Created featureGraphic.png"
else
    echo "  ⚠ featureGraphic.svg not found, skipping..."
fi

echo ""
echo "✓ Conversion complete!"
echo ""
echo "Generated files:"
ls -lh *.png 2>/dev/null || echo "  (no PNG files found)"

