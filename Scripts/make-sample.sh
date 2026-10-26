#!/bin/bash
# Generates a ~5 MB notes file with separators and code blocks for load testing.
set -euo pipefail
out="${1:?usage: make-sample.sh OUTPUT}"
mkdir -p "$(dirname "$out")"
: > "$out"
i=0
while [ "$(stat -f%z "$out")" -lt 5000000 ]; do
  i=$((i + 1))
  d=$(date -v-"${i}"H "+%Y-%m-%d %H:%M")
  cat >> "$out" <<NOTE

--------------------< $d >--------------------
# Entry $i
Some **bold** text, *italic*, \`inline\` and a link https://example.com/$i
- [ ] todo item $i
- [x] done item
> quoted thought

\`\`\`json
{"id": $i, "ok": true, "name": "entry-$i", "tags": null}
\`\`\`

\`\`\`sql
SELECT id, name FROM entries WHERE id = $i -- lookup
\`\`\`

\`\`\`go
func f$i() error { return nil } // noop
\`\`\`
NOTE
done
echo "wrote $out ($(stat -f%z "$out") bytes, $i entries)"
