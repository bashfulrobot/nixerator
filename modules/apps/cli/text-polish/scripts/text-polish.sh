#!/usr/bin/env bash
set -euo pipefail

# Tool paths are substituted by Nix
WL_PASTE="@wl_paste@"
WL_COPY="@wl_copy@"
NOTIFY="@notify_send@"
WTYPE="@wtype@"
JQ="@jq@"

# The rewrite pipeline (rules, isolation, marker extraction, safety filters)
# lives in text-polish-core.sh, shared with polish-editor.sh. Only the Wayland
# I/O layer is here. TEXT_POLISH_CORE lets the test harness source the
# unsubstituted file.
# shellcheck source=text-polish-core.sh
. "${TEXT_POLISH_CORE:-@core@}"

NOTIFY_TAG="text-polish"

notify() {
  "$NOTIFY" "Text Polish" "$1" --icon=accessories-text-editor \
    --hint=string:x-dunst-stack-tag:"$NOTIFY_TAG" 2>/dev/null || true
}

notify_error() {
  "$NOTIFY" "Text Polish" "$1" --icon=dialog-error \
    --hint=string:x-dunst-stack-tag:"$NOTIFY_TAG" 2>/dev/null || true
}

main() {
  # 1. Grab text: primary selection first, then clipboard
  local input=""
  input=$("$WL_PASTE" --primary --no-newline 2>/dev/null) || true
  if [ -z "$input" ]; then
    input=$("$WL_PASTE" --no-newline 2>/dev/null) || true
  fi

  if [ -z "$input" ]; then
    notify_error "No text selected or on clipboard"
    exit 1
  fi

  polish_check "$input" || {
    notify_error "$PT_ERR"
    exit 1
  }

  # Record the focused window so we only paste back into it (see step 4).
  local win_before
  win_before=$(hyprctl activewindow -j 2>/dev/null | "$JQ" -r '.address // empty' 2>/dev/null || true)

  notify "Polishing ${#input} characters..."

  # 2. Rewrite. Fails closed: nothing is pasted unless the result passed the
  # core's safety filter.
  polish_run "$input" || {
    notify_error "$PT_ERR"
    exit 1
  }
  local output="$PT_OUT"

  # 3. Put the validated result on the clipboard
  printf '%s' "$output" | "$WL_COPY"

  # 4. Paste back — but only into the SAME window that was focused when the
  # shortcut fired. If focus moved during the model round-trip, withhold the
  # paste so the rewrite can't land in the wrong field; leave it on the clipboard
  # for a manual Ctrl+V. Focus detection is best-effort: if the window could not
  # be read, fall through to pasting (preserving prior behaviour).
  sleep 1
  if [ -n "$win_before" ]; then
    local win_after
    win_after=$(hyprctl activewindow -j 2>/dev/null | "$JQ" -r '.address // empty' 2>/dev/null || true)
    if [ -n "$win_after" ] && [ "$win_after" != "$win_before" ]; then
      notify "Focus changed — result is on the clipboard, press Ctrl+V"
      exit 0
    fi
  fi
  "$WTYPE" -M ctrl -P v -p v -m ctrl 2>/dev/null || true

  # 5. Notify success with preview
  local preview="${output:0:120}"
  if [ ${#output} -gt 120 ]; then
    preview="${preview}..."
  fi
  notify "Copied to clipboard
${preview}"
}

# Allow the file to be sourced for testing (TEXT_POLISH_LIB=1) without running.
if [ "${TEXT_POLISH_LIB:-}" != "1" ]; then
  main "$@"
fi
