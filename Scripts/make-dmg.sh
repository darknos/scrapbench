#!/bin/sh
# Packs a signed app bundle into a plain disk image: the app next to an
# `Applications` symlink, compressed, signed with the same identity as the app.
# Usage: Scripts/make-dmg.sh <App.app> <out.dmg> [signing identity, default "-"]
set -eu
app="$1"; out="$2"; sign="${3:--}"
name="$(basename "$app" .app)"

work="$(mktemp -d)"
staging="$work/$name"
mkdir -p "$staging"
ditto "$app" "$staging/$(basename "$app")"
ln -s /Applications "$staging/Applications"
rm -f "$out"
hdiutil create -quiet -volname "$name" -srcfolder "$staging" -fs HFS+ -format UDZO "$out"
rm -rf "$work"
if [ "$sign" != "-" ]; then
    codesign --force --sign "$sign" --timestamp "$out"
fi
echo "disk image: $out"
