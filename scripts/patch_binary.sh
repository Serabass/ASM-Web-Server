#!/usr/bin/env bash
# Patch placeholders in the ASM server binary: Content-Length, BINSIZE, IMGSIZE, GITHUB URL.
# Usage: BINARY_SIZE=12345 IMAGE_SIZE=1.2MiB GITHUB_URL=https://... ./patch_binary.sh /path/to/server
set -e
SERVER="${1:-/build/server}"
if [ ! -f "$SERVER" ]; then
  echo "Usage: $0 /path/to/binary" >&2
  exit 1
fi

# BINARY_SIZE from env or from file size
BINARY_SIZE="${BINARY_SIZE:-$(stat -c%s "$SERVER" 2>/dev/null || echo 0)}"
IMAGE_SIZE="${IMAGE_SIZE:-N/A}"
GITHUB_URL="${GITHUB_URL:-https://github.com/your-org/asm-server}"

# Content-Length: only replace placeholder 0000; embed script already sets correct length
start=$(grep -bo '<!DOCTYPE' "$SERVER" 2>/dev/null | head -1 | cut -d: -f1)
end=$(grep -bo '</html>' "$SERVER" 2>/dev/null | head -1 | cut -d: -f1)
if [ -n "$start" ] && [ -n "$end" ]; then
  body_len=$((end + 7 - start))
  cl_value=$(printf '%04d' "$body_len")
  sed -i "s|Content-Length: 0000|Content-Length: $cl_value|" "$SERVER"
  echo "Patched: Content-Length=$cl_value"
else
  # Do not overwrite embed's Content-Length with fallback 500
  echo "Patched: Content-Length left as-is (no 0000 placeholder or grep failed)"
  cl_value="(unchanged)"
fi

# 20-char placeholders after <!--BINSIZE--> and <!--IMGSIZE-->
binsize_text=$(printf '%-20s' "${BINARY_SIZE} bytes")
imgsize_text=$(printf '%-20s' "$IMAGE_SIZE")
dots20='....................'
sed -i "s|<!--BINSIZE-->$dots20|<!--BINSIZE-->$binsize_text|" "$SERVER"
sed -i "s|<!--IMGSIZE-->$dots20|<!--IMGSIZE-->$imgsize_text|" "$SERVER"

# 80-char URL: replace the default URL+spaces block with new URL padded to 80
old_github_80=$(printf '%-80s' 'https://github.com/your-org/asm-server')
new_github_80=$(printf '%-80s' "$GITHUB_URL")
# Use # delimiter (not in URL); escape & in replacement as \&
new_escaped=$(echo "$new_github_80" | sed 's/[\&]/\\\&/g')
sed -i "s#$old_github_80#$new_escaped#" "$SERVER" 2>/dev/null || true

echo "Patched: Content-Length=$cl_value BINARY_SIZE=$BINARY_SIZE IMAGE_SIZE=$IMAGE_SIZE"
