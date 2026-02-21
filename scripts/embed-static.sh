#!/usr/bin/env bash
# Read static/index.html, build HTTP response (headers + body), write raw bytes to src/response_index.bin
set -e
ROOT="${1:-.}"
INDEX="${ROOT}/static/index.html"
OUT="${ROOT}/src/response_index.bin"
if [ ! -f "$INDEX" ]; then
  echo "Missing $INDEX" >&2
  exit 1
fi
mkdir -p "$(dirname "$OUT")"
BODY=$(cat "$INDEX")
BODY_LEN=$(printf '%s' "$BODY" | wc -c)
[ "$BODY_LEN" -gt 0 ] || { echo "Empty or missing body from $INDEX" >&2; exit 1; }
HEADERS="HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\nContent-Length: ${BODY_LEN}\r\n\r\n"
printf "%b%s" "$HEADERS" "$BODY" > "$OUT"
echo "Embedded $(wc -c < "$OUT") bytes (body=$BODY_LEN) -> $OUT"
