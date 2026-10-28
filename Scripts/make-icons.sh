#!/bin/sh
# Renders Resources/Icon/*.svg into AppIcon.icns and the menu bar template PNGs.
# Usage: Scripts/make-icons.sh <output dir>
set -eu
out="$1"
src="$(dirname "$0")/../Resources/Icon"
command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found: brew install librsvg" >&2; exit 1; }

iconset="$out/AppIcon.iconset"
rm -rf "$iconset"; mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    rsvg-convert -w "$size" -h "$size" "$src/AppIcon.svg" -o "$iconset/icon_${size}x${size}.png"
    double=$((size * 2))
    rsvg-convert -w "$double" -h "$double" "$src/AppIcon.svg" -o "$iconset/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$iconset" -o "$out/AppIcon.icns"
rm -rf "$iconset"

rsvg-convert -w 18 -h 18 "$src/MenuIcon.svg" -o "$out/MenuIcon.png"
rsvg-convert -w 36 -h 36 "$src/MenuIcon.svg" -o "$out/MenuIcon@2x.png"
