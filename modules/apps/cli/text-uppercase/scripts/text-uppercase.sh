#!/usr/bin/env bash
set -euo pipefail

# Tool paths are substituted by Nix
WL_PASTE="@wl_paste@"
WL_COPY="@wl_copy@"
NOTIFY="@notify_send@"
TR="@tr@"
WTYPE="@wtype@"

NOTIFY_TAG="text-uppercase"

notify() {
  "$NOTIFY" "Text Uppercase" "$1" --icon=accessories-text-editor \
    --hint=string:x-dunst-stack-tag:"$NOTIFY_TAG" 2>/dev/null || true
}

notify_error() {
  "$NOTIFY" "Text Uppercase" "$1" --icon=dialog-error \
    --hint=string:x-dunst-stack-tag:"$NOTIFY_TAG" 2>/dev/null || true
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

# 2. Uppercase it
output=$(printf '%s' "$input" | "$TR" '[:lower:]' '[:upper:]')

# 3. Put result on clipboard
printf '%s' "$output" | "$WL_COPY"

# 4. Paste back — wait for shortcut's modifiers to release, then send Ctrl+V
sleep 1
"$WTYPE" -M ctrl -P v -p v -m ctrl 2>/dev/null || true

# 5. Notify success with preview
preview="${output:0:120}"
if [ ${#output} -gt 120 ]; then
  preview="${preview}..."
fi
notify "Copied to clipboard
${preview}"
