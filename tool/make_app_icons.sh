#!/usr/bin/env bash
# Regenerates the iOS, macOS and Android app icons from the store icon SVG. Needs rsvg-convert and magick.
# Usage: tool/make_app_icons.sh [android|ios|macos|all]  (default all)
set -euo pipefail
cd "$(dirname "$0")/.."

svg=android/fastlane/metadata/android/de-DE/images/icon.svg
ios=ios/Runner/Assets.xcassets/AppIcon.appiconset
macos=macos/Runner/Assets.xcassets/AppIcon.appiconset
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

ios_icons() {
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
}

macos_icons() {
  # macOS keeps the rounded shape of the SVG.
  for f in "$macos"/app_icon_*.png; do
    px=$(basename "$f" .png); px=${px#app_icon_}
    rsvg-convert -w "$px" -h "$px" "$svg" -o "$f"
  done
}

# Android launcher icons: the plain icon keeps the rounded shape with transparent corners.
# The adaptive foreground is the SVG without background rect, border and corner marks,
# zoomed out so the glyph sits inside the 66 of 108 dp safe zone (the dots' circle, 350 units, spans 66 dp).
android_icons() {
  res=android/app/src/main/res
  grep -v -e '<rect' -e '<path' "$svg" \
    | sed 's/viewBox="0 0 512 512"/viewBox="-34 -27 580 580"/' > "$tmp/fg.svg"
  for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
    px=${d#*:}; dir=$res/mipmap-${d%%:*}
    rsvg-convert -w "$px" -h "$px" "$svg" -o "$dir/ic_launcher.png"
    rsvg-convert -w "$((px * 9 / 4))" -h "$((px * 9 / 4))" "$tmp/fg.svg" -o "$dir/ic_launcher_foreground.png"
  done
}

case "${1:-all}" in
  android) android_icons ;;
  ios) ios_icons ;;
  macos) macos_icons ;;
  all) ios_icons; macos_icons; android_icons ;;
  *) echo "usage: $0 [android|ios|macos|all]" >&2; exit 1 ;;
esac
