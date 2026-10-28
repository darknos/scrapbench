#!/bin/sh
# Notarizes a signed app bundle with an App Store Connect API key, staples the
# ticket and writes a zip ready for a release.
# Usage: Scripts/notarize.sh <App.app> <out.zip>
# Env:   APPLE_API_KEY_PATH (.p8 file), APPLE_API_KEY_ID, APPLE_API_ISSUER_ID
set -eu
app="$1"; out="$2"
: "${APPLE_API_KEY_PATH:?}" "${APPLE_API_KEY_ID:?}" "${APPLE_API_ISSUER_ID:?}"

work="$(mktemp -d)"
ditto -c -k --keepParent "$app" "$work/submit.zip"
xcrun notarytool submit "$work/submit.zip" \
    --key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID" \
    --wait --timeout 30m
xcrun stapler staple "$app"
spctl --assess --type execute --verbose=2 "$app"
rm -f "$out"
ditto -c -k --keepParent "$app" "$out"
rm -rf "$work"
echo "notarized and stapled: $out"
