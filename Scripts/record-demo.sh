#!/bin/sh
# Records the README demo: open → paste or type → ⌘K transformer → Esc, four scraps on a scratch file.
# Usage: Scripts/record-demo.sh <output.gif>
# Needs: a built build/Scrapbench.app, gifski, ffmpeg, accessibility access for the terminal.
# The panel is captured where it currently is; place and size it before running.
set -eu
out="$1"
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
driver="$work/demo-driver"
swiftc -O "$root/Scripts/demo-driver.swift" -o "$driver" 2>/dev/null

: > "$work/scrapbench.md"
pkill -x Scrapbench || true
defaults write org.nosenko.Scrapbench filePath "$work/scrapbench.md"
clip="$(pbpaste 2>/dev/null || true)"
restore() { defaults delete org.nosenko.Scrapbench filePath; pkill -x Scrapbench || true; printf '%s' "$clip" | pbcopy; }
trap restore EXIT
sleep 1
open "$root/build/Scrapbench.app" || { sleep 2; open "$root/build/Scrapbench.app"; }
sleep 2

"$driver" open sleep:1.5
frame="$(osascript -e 'tell application "System Events" to tell process "Scrapbench" to get {position, size} of window 1' | tr -d ',')"
set -- $frame
x=$(( $1 - 24 )); y=$(( $2 - 24 )); w=$(( $3 + 48 )); h=$(( $4 + 48 ))
"$driver" esc sleep:1

"$driver" "backdrop:$x,$y,$w,$h" &
backdrop=$!
sleep 0.8
screencapture -v -x -V 50 -R"$x,$y,$w,$h" "$work/demo.mov" &
rec=$!
sleep 1
start=$(date +%s)
"$driver" \
    open sleep:1.4 \
    "clip:curl -X POST https://api.example.com/v1/deploys -H 'Authorization: Bearer \$TOKEN' -H 'Content-Type: application/json' -d '{\"service\":\"api\",\"ref\":\"v2.14.0\"}'" \
    "cmd:v" sleep:1.2 "cmd:k" sleep:0.8 "type:split command" sleep:0.6 enter sleep:2.2 esc sleep:1.4 \
    open sleep:1.4 \
    'clip:{"id":8812,"status":"queued","service":"api","ref":"v2.14.0","steps":[{"name":"build","ok":true},{"name":"migrate","ok":null}]}' \
    "cmd:v" sleep:1.2 "cmd:k" sleep:0.8 "type:pretty" sleep:0.6 enter sleep:2.2 esc sleep:1.4 \
    open sleep:1.4 \
    "type:1793203200" sleep:0.5 "cmd:k" sleep:0.8 "type:epoch" sleep:0.6 enter sleep:1.6 \
    "cmd:n" sleep:0.8 "type:4096 * 1024 / 7" sleep:0.5 "cmd:k" sleep:0.8 "type:calc" sleep:0.6 enter sleep:1.8 esc sleep:1.4 \
    open sleep:1.4 \
    "type:admin:s3cret" sleep:0.5 "cmd:k" sleep:0.8 "type:base64 enc" sleep:0.6 enter sleep:2 esc sleep:1.6
length=$(( $(date +%s) - start + 2 ))
wait "$rec"
kill "$backdrop"

ffmpeg -loglevel error -y -t "$length" -i "$work/demo.mov" -vf "fps=15,scale=800:-1:flags=lanczos" "$work/frame%04d.png"
gifski --fps 15 --quality 85 -o "$out" "$work"/frame*.png
rm -rf "$work"
echo "wrote $out"
