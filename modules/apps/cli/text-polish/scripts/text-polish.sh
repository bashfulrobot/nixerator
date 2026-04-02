#!/usr/bin/env bash
set -euo pipefail

# Tool paths are substituted by Nix
WL_PASTE="@wl_paste@"
WL_COPY="@wl_copy@"
NOTIFY="@notify_send@"

NOTIFY_TAG="text-polish"

notify() {
  "$NOTIFY" "Text Polish" "$1" --icon=accessories-text-editor \
    --hint=string:x-dunst-stack-tag:$NOTIFY_TAG 2>/dev/null || true
}

notify_error() {
  "$NOTIFY" "Text Polish" "$1" --icon=dialog-error \
    --hint=string:x-dunst-stack-tag:$NOTIFY_TAG 2>/dev/null || true
}

# 1. Grab text: primary selection first, then clipboard
input=""
input=$("$WL_PASTE" --primary --no-newline 2>/dev/null) || true
if [ -z "$input" ]; then
  input=$("$WL_PASTE" --no-newline 2>/dev/null) || true
fi

if [ -z "$input" ]; then
  notify_error "No text selected or on clipboard"
  exit 1
fi

# Guard against huge text
char_count=${#input}
if [ "$char_count" -gt 10000 ]; then
  notify_error "Text too long (${char_count} chars, max 10000)"
  exit 1
fi

notify "Polishing ${char_count} characters..."

# 2. Build prompt and send to Claude
read -r -d '' PROMPT <<'PROMPT_END' || true
Rewrite the following text. Say the same thing in as few words as possible. Output ONLY the rewritten text, nothing else — no preamble, no explanation, no quotes around it.

Rules:
- Be ruthlessly concise — cut every unnecessary word, merge redundant sentences, eliminate fluff
- Fix grammar and spelling errors
- Preserve the original tone (casual stays casual, formal stays formal, technical stays technical)
- Preserve the original meaning, but use fewer words to express it
- Preserve the original language (do not translate)
- If the input is casual or short (like a chat message), keep the output casual and short

Anti-slop rules (critical — the output must not sound AI-generated):
- Never use: additionally, crucial, delve, enhance, foster, landscape, pivotal, showcase, testament, underscore, vibrant, tapestry, intricate, garner, enduring, groundbreaking, nestled, renowned, seamless, utilize
- Use simple verbs: "is" not "serves as", "has" not "boasts"
- No em dash overuse — prefer commas or periods
- No rule-of-three patterns (grouping ideas into threes)
- No negative parallelisms ("not just X, but Y")
- No significance inflation ("marking a pivotal moment")
- No promotional or sycophantic language
- No filler phrases ("In order to", "It is important to note that", "At the end of the day")
- Vary sentence length naturally

Text to rewrite:
PROMPT_END

output=$(printf '%s\n\n%s' "$PROMPT" "$input" | claude -p 2>/dev/null) || {
  notify_error "Claude failed — check API key or network"
  exit 1
}

if [ -z "$output" ]; then
  notify_error "Claude returned empty output"
  exit 1
fi

# 3. Put result on clipboard
printf '%s' "$output" | "$WL_COPY"

# 4. Notify success with preview
preview="${output:0:120}"
if [ ${#output} -gt 120 ]; then
  preview="${preview}..."
fi
notify "Copied to clipboard
${preview}"
