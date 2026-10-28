#!/bin/sh
# Records the README demo: three open → type → Esc cycles on a scratch file.
# Usage: Scripts/record-demo.sh <output.gif>
# Needs: a built build/Scrapbench.app, gifski, ffmpeg, accessibility access for the terminal.
# The panel is captured where it currently is; place and size it before running.
set -eu
out="$1"
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
driver="$work/demo-driver"
swiftc -O "$root/Scripts/demo-driver.swift" -o "$driver" 2>/dev/null

: > "$work/demo.md"
pkill -x Scrapbench || true
defaults write org.nosenko.Scrapbench filePath "$work/demo.md"
restore() { defaults delete org.nosenko.Scrapbench filePath; pkill -x Scrapbench || true; }
trap restore EXIT
open "$root/build/Scrapbench.app"; sleep 1.5

"$driver" open sleep:1.5
frame="$(osascript -e 'tell application "System Events" to tell process "Scrapbench" to get {position, size} of window 1' | tr -d ',')"
set -- $frame
x=$(( $1 - 24 )); y=$(( $2 - 24 )); w=$(( $3 + 48 )); h=$(( $4 + 48 ))
"$driver" esc sleep:1

screencapture -v -x -V 24 -R"$x,$y,$w,$h" "$work/demo.mov" &
rec=$!
sleep 1.5
"$driver" open sleep:1.6 \
    "type:deploy notes: rotate the api key before friday" sleep:1.2 esc sleep:1.8 \
    open sleep:1.6 \
    "type:\`\`\`sh\nkubectl rollout restart deploy/api -n prod\n\`\`\`" sleep:1.4 esc sleep:1.8 \
    open sleep:1.6 \
    "type:- [ ] tell ops about the restart" sleep:1.2 esc sleep:1.5
wait "$rec"

ffmpeg -loglevel error -y -i "$work/demo.mov" -vf "fps=15,scale=800:-1:flags=lanczos" "$work/frame%04d.png"
gifski --fps 15 --quality 85 -o "$out" "$work"/frame*.png
rm -rf "$work"
echo "wrote $out"
