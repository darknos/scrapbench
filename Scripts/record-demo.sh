#!/bin/sh
# Records the README demo: one open, five scraps separated by ⌘N (built-in transformers, then
# the Corporate style script while typing goes on, two more built-ins under it), Esc at the end.
# Runs on a scratch file.
# Usage: Scripts/record-demo.sh <output.gif>
# Needs: a built build/Scrapbench.app, gifski, ffmpeg, accessibility access for the terminal,
# and the Claude Code CLI signed in (Examples/transformers/corporate-style.sh is installed for the run).
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
last="$(defaults read org.nosenko.Scrapbench lastTransformer 2>/dev/null || true)"
defaults delete org.nosenko.Scrapbench lastTransformer 2>/dev/null || true
wrap="$(defaults read org.nosenko.Scrapbench wordWrap 2>/dev/null || true)"
defaults write org.nosenko.Scrapbench wordWrap -bool true
scripts="$HOME/Library/Application Support/Scrapbench/Transformers"
installed=""
if [ ! -e "$scripts/corporate-style.sh" ]; then
    mkdir -p "$scripts"
    cp "$root/Examples/transformers/corporate-style.sh" "$scripts/"
    installed="$scripts/corporate-style.sh"
fi
clip="$(pbpaste 2>/dev/null || true)"
restore() {
    defaults delete org.nosenko.Scrapbench filePath
    if [ -n "$last" ]; then defaults write org.nosenko.Scrapbench lastTransformer "$last"; fi
    if [ -n "$wrap" ]; then defaults write org.nosenko.Scrapbench wordWrap -bool "$wrap"; else defaults delete org.nosenko.Scrapbench wordWrap 2>/dev/null || true; fi
    [ -n "$installed" ] && rm -f "$installed"
    pkill -x Scrapbench || true
    printf '%s' "$clip" | pbcopy
}
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
# The panel is open before the recording starts and the final Esc comes after
# the cut point, so the GIF has no empty frames at either end.
"$driver" open sleep:1
screencapture -v -x -V 75 -R"$x,$y,$w,$h" "$work/demo.mov" &
rec=$!
sleep 1
start=$(date +%s)
"$driver" \
    "clip:curl -X POST https://api.example.com/v1/deploys -H 'Authorization: Bearer \$TOKEN' -H 'Content-Type: application/json' -d '{\"service\":\"api\",\"ref\":\"v2.14.0\"}'" \
    "cmd:v" sleep:1 "cmd:k" sleep:0.5 "type:split command" sleep:0.4 enter sleep:1.5 \
    "cmd:n" sleep:0.6 \
    'clip:{"id":8812,"status":"queued","service":"api","ref":"v2.14.0","steps":[{"name":"build","ok":true},{"name":"migrate","ok":null}]}' \
    "cmd:v" sleep:1 "cmd:k" sleep:0.5 "type:pretty" sleep:0.4 enter sleep:1.5 \
    "cmd:n" sleep:0.6 \
    "type:1793203200" sleep:0.4 "cmd:k" sleep:0.5 "type:epoch" sleep:0.4 enter sleep:1.3 \
    "cmd:n" sleep:0.6 \
    "type:4096 * 1024 / 7" sleep:0.4 "cmd:k" sleep:0.5 "type:calc" sleep:0.4 enter sleep:1.3 \
    "cmd:n" sleep:0.6 \
    "type:you people are fucking useless, I'm sick of doing everyone's damn job on my own" sleep:0.5 \
    "cmd:k" sleep:0.5 "type:corporate" sleep:0.4 enter sleep:0.8 \
    "cmd:n" sleep:0.4 "type:meanwhile, the bench stays yours: keep typing while the script thinks" sleep:4 \
    "cmd:n" sleep:0.6 \
    "clip:https://example.com/search?q=caf%C3%A9%20au%20lait&lang=en" \
    "cmd:v" sleep:0.8 "cmd:k" sleep:0.5 "type:url dec" sleep:0.4 enter sleep:1.3 \
    "cmd:n" sleep:0.6 \
    "type:admin:s3cret" sleep:0.4 "cmd:k" sleep:0.5 "type:base64 enc" sleep:0.4 enter sleep:2
length=$(( $(date +%s) - start ))
"$driver" esc
wait "$rec"
kill "$backdrop"

ffmpeg -loglevel error -y -t "$length" -i "$work/demo.mov" -vf "fps=15,scale=800:-1:flags=lanczos" "$work/frame%04d.png"
gifski --fps 15 --quality 85 -o "$out" "$work"/frame*.png
rm -rf "$work"
echo "wrote $out"
