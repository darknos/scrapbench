#!/bin/sh
# Notarizes a signed app bundle or a disk image with an App Store Connect API
# key and staples the ticket. For an app bundle, also writes a zip ready for a
# release; for a disk image, the stapled image itself is the release file.
# Usage: Scripts/notarize.sh <App.app> <out.zip>
#        Scripts/notarize.sh <Image.dmg>
# Env:   APPLE_API_KEY_PATH (.p8 file), APPLE_API_KEY_ID, APPLE_API_ISSUER_ID
set -eu
target="$1"; out="${2:-}"
: "${APPLE_API_KEY_PATH:?}" "${APPLE_API_KEY_ID:?}" "${APPLE_API_ISSUER_ID:?}"

work="$(mktemp -d)"
case "$target" in
    *.dmg) submit="$target" ;;
    *) submit="$work/submit.zip"; ditto -c -k --keepParent "$target" "$submit" ;;
esac
xcrun notarytool submit "$submit" \
    --key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID" \
    --wait --timeout 30m
xcrun stapler staple "$target"
case "$target" in
    *.dmg)
        spctl --assess --type open --context context:primary-signature --verbose=2 "$target"
        echo "notarized and stapled: $target" ;;
    *)
        : "${out:?an output zip is needed for an app bundle}"
        spctl --assess --type execute --verbose=2 "$target"
        rm -f "$out"
        ditto -c -k --keepParent "$target" "$out"
        echo "notarized and stapled: $out" ;;
esac
rm -rf "$work"
