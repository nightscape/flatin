#!/usr/bin/env bash
# Regenerates the iOS and macOS app icons from the store icon SVG. Needs rsvg-convert and magick.
set -euo pipefail
cd "$(dirname "$0")/.."

svg=android/fastlane/metadata/android/de-DE/images/icon.svg
ios=ios/Runner/Assets.xcassets/AppIcon.appiconset
macos=macos/Runner/Assets.xcassets/AppIcon.appiconset
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# iOS applies its own mask: square, fully opaque artwork.
sed 's/rx="96"/rx="0"/' "$svg" > "$tmp/ios.svg"
rsvg-convert -w 1024 -h 1024 "$tmp/ios.svg" -o "$tmp/ios1024.png"

for f in "$ios"/Icon-App-*.png; do
  name=$(basename "$f" .png)
  size=${name#Icon-App-}; size=${size%@*}
  scale=${name##*@}; scale=${scale%x}
  px=$(awk -v s="${size%%x*}" -v k="$scale" 'BEGIN { printf "%d", s * k + 0.5 }')
  magick "$tmp/ios1024.png" -resize "${px}x${px}" -background '#1a237e' -alpha remove -alpha off "$f"
done

# macOS keeps the rounded shape of the SVG.
for f in "$macos"/app_icon_*.png; do
  px=$(basename "$f" .png); px=${px#app_icon_}
  rsvg-convert -w "$px" -h "$px" "$svg" -o "$f"
done
