#!/usr/bin/env bash
# key-magenta.sh -- key a flat key-colour background out of a render into a real
# RGBA PNG, then verify the alpha from the file bytes (the previewer lies).
#
# Usage:
#   key-magenta.sh IN OUT [KEY] [SIMILARITY] [BLEND]
#
#   IN          input render (magenta-backed), PNG or JPEG
#   OUT         output RGBA PNG
#   KEY         key colour, default 0xFF00FF (magenta)
#   SIMILARITY  how far from KEY still counts as background, default 0.32
#               (bump toward 0.40 for Gemini JPEG output)
#   BLEND       edge softness, default 0.12
#
# Exits non-zero if the output is not real RGBA or the corner is not transparent.
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: key-magenta.sh IN OUT [KEY] [SIMILARITY] [BLEND]" >&2
  exit 2
fi

in="$1"
out="$2"
key="${3:-0xFF00FF}"
sim="${4:-0.32}"
blend="${5:-0.12}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "key-magenta: ffmpeg not found on PATH" >&2
  exit 1
fi
if [ ! -f "$in" ]; then
  echo "key-magenta: input not found: $in" >&2
  exit 1
fi

ffmpeg -y -loglevel error -i "$in" \
  -vf "colorkey=${key}:${sim}:${blend},format=rgba" \
  -frames:v 1 "$out"

# --- verify the alpha is real, from the bytes ---

# PNG IHDR colour type is byte 25 (0-indexed). 6 = truecolour+alpha. 2 = RGB.
ctype="$(od -A n -t u1 -j 25 -N 1 "$out" | tr -d ' ')"
if [ "$ctype" != "6" ]; then
  echo "key-magenta: FAIL colour type is $ctype, expected 6 (RGBA). Output is not transparent." >&2
  exit 1
fi

# Corner pixel (top-left, background) alpha byte must be 0. Read one pixel
# (4 bytes R G B A) and take the 4th numeric byte; filtering to numeric tokens
# avoids the leading-whitespace token od emits.
corner_alpha="$(ffmpeg -hide_banner -i "$out" -vf "crop=1:1:0:0,format=rgba" \
  -f rawvideo - 2>/dev/null | od -A n -t u1 | tr -s ' ' '\n' |
  grep -E '^[0-9]+$' | sed -n '4p')"
if [ "${corner_alpha:-x}" != "0" ]; then
  echo "key-magenta: WARN corner alpha is ${corner_alpha:-unknown}, expected 0." >&2
  echo "             The key colour or tolerance may be off for this image." >&2
  exit 1
fi

echo "key-magenta: ok -> $out (RGBA, corner transparent)"
