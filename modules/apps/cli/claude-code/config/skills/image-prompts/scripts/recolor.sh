#!/usr/bin/env bash
# recolor.sh -- replace one flat source colour with a target colour, preserving
# every pixel of content (deterministic re-theme; no generative model).
#
# Flattens shading within the swapped region (flat fill in -> flat fill out),
# which is correct for solid UI colours and brand fills. For graded colours or
# photos use a curves / hue / lut3d pass instead (see retheme-screenshot.md).
#
# Usage:
#   recolor.sh IN OUT SRC DST [SIMILARITY] [BLEND]
#
#   IN          input image
#   OUT         output PNG
#   SRC         source colour to replace, hex with or without # (e.g. 2962FF)
#   DST         target colour, hex with or without # (e.g. CCFF00)
#   SIMILARITY  match tolerance around SRC, default 0.15
#               (raise to catch anti-aliased edges, lower to protect nearby hues)
#   BLEND       edge softness, default 0.05
set -euo pipefail

if [ "$#" -lt 4 ]; then
  echo "usage: recolor.sh IN OUT SRC DST [SIMILARITY] [BLEND]" >&2
  exit 2
fi

in="$1"
out="$2"
src="0x${3#\#}"
dst="0x${4#\#}"
sim="${5:-0.15}"
blend="${6:-0.05}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "recolor: ffmpeg not found on PATH" >&2
  exit 1
fi
if [ ! -f "$in" ]; then
  echo "recolor: input not found: $in" >&2
  exit 1
fi

# Build a DST-coloured plate the size of the input, key SRC out of the input to
# alpha, then composite the keyed input over the plate so SRC pixels show DST.
ffmpeg -y -loglevel error -i "$in" -filter_complex \
  "color=c=${dst}:s=16x16[plate]; \
   [plate][0:v]scale2ref[bg][base]; \
   [base]format=rgba,colorkey=${src}:${sim}:${blend}[fg]; \
   [bg][fg]overlay=format=auto,format=rgba" \
  -frames:v 1 "$out"

echo "recolor: ok -> $out (${3} -> ${4})"
echo "recolor: review at full size; confirm no text edge was eaten and DST matches the deck hex."
