#!/usr/bin/env bash
# zoom-join — open a Zoom/Clari meeting in the dedicated Zoom web-client PWA.
#
# Reads a meeting reference from $1 (if given) or the clipboard, extracts the
# meeting id (+ passcode), and launches the Zoom PWA profile straight into the
# web client. Bound to a hotkey via the clipboard-join.nix module.
#
# Recognised inputs (id is always normalised to digits only):
#   https://<sub>.zoom.us/j/<id>?pwd=<tok>         (Redirector / calendar form)
#   https://<sub>.zoom.us/wc/join/<id>?pwd=<tok>
#   https://<sub>.zoom.us/wc/<id>/join?pwd=<tok>
#   https://<sub>.zoom.us/s/<id>
#   zoommtg://zoom.us/join?confno=<id>&pwd=<tok>
#   https://go.copilot.clari.com/zoom/<id>/s/<tok>
#   <id>  bare meeting id, e.g. 123-4567-8901 or "123 4567 8901"
#
# For *.zoom.us inputs the original subdomain is preserved (most reliable for
# region-pinned meetings); hostless inputs (zoommtg / Clari / bare id) use
# app.zoom.us. Passcode is passed through when present.
#
# DRY=1 prints the launch command instead of running it (for testing).
set -uo pipefail

WL_PASTE="@wl_paste@"
NOTIFY="@notify_send@"
BROWSER="@browser@"
PROFILE="@profile@"

NOTIFY_TAG="zoom-join"

notify() { "$NOTIFY" "Zoom" "$1" --icon=camera-web --hint=string:x-dunst-stack-tag:"$NOTIFY_TAG" 2>/dev/null || true; }
notify_error() { "$NOTIFY" "Zoom" "$1" --icon=dialog-error --hint=string:x-dunst-stack-tag:"$NOTIFY_TAG" 2>/dev/null || true; }

host_of() { printf '%s' "$1" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://([^/?#]+).*#\1#'; }
qparam() { printf '%s' "$1" | grep -oE "[?&]$2=[^&#]*" | head -n1 | sed -E "s/^[?&]$2=//" || true; }

# Input: explicit arg wins, else clipboard, else primary selection.
input="${1:-}"
if [ -z "$input" ]; then
  input="$("$WL_PASTE" --no-newline 2>/dev/null || true)"
  [ -z "$input" ] && input="$("$WL_PASTE" --primary --no-newline 2>/dev/null || true)"
fi
# Trim surrounding whitespace / stray CRs.
input="$(printf '%s' "$input" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [ -z "$input" ]; then
  notify_error "Nothing on the clipboard"
  exit 1
fi

host=""
id=""
pwd=""
case "$input" in
  zoommtg://*)
    host="app.zoom.us"
    id="$(qparam "$input" confno)"
    pwd="$(qparam "$input" pwd)"
    ;;
  http://* | https://*)
    h="$(host_of "$input")"
    case "$h" in
      zoom.us | *.zoom.us)
        host="$h"
        id="$(printf '%s' "$input" | sed -nE 's#^https?://[^/]+/(j|wc/join|s)/([0-9]+).*#\2#p')"
        [ -z "$id" ] && id="$(printf '%s' "$input" | sed -nE 's#^https?://[^/]+/wc/([0-9]+)/join.*#\1#p')"
        pwd="$(qparam "$input" pwd)"
        ;;
      go.copilot.clari.com)
        host="app.zoom.us"
        id="$(printf '%s' "$input" | sed -nE 's#^https?://[^/]+/zoom/([0-9]+)/s/([^/?#]+).*#\1#p')"
        pwd="$(printf '%s' "$input" | sed -nE 's#^https?://[^/]+/zoom/([0-9]+)/s/([^/?#]+).*#\2#p')"
        ;;
      *)
        notify_error "Not a Zoom/Clari link: $h"
        exit 1
        ;;
    esac
    ;;
  *)
    # Bare meeting id (digits, possibly with dashes/spaces).
    stripped="$(printf '%s' "$input" | tr -d ' -')"
    if printf '%s' "$stripped" | grep -qE '^[0-9]{9,12}$'; then
      host="app.zoom.us"
      id="$stripped"
    else
      notify_error "No Zoom/Clari link or meeting ID on clipboard"
      exit 1
    fi
    ;;
esac

# Normalise the meeting id to digits only (strips dashes/spaces from any source).
id="$(printf '%s' "$id" | tr -cd '0-9')"
if [ -z "$id" ]; then
  notify_error "Could not find a meeting ID"
  exit 1
fi

target="https://${host}/wc/join/${id}"
[ -n "$pwd" ] && target="${target}?pwd=${pwd}"

if [ "${DRY:-0}" = 1 ]; then
  printf 'zoom-join: would launch meeting %s\n  %s --app=%s\n' "$id" "$BROWSER" "$target"
  exit 0
fi

notify "Joining meeting ${id}…"
exec "$BROWSER" --no-first-run --new-instance --app="$target" \
  --user-data-dir="$PROFILE" --password-store=gnome-libsecret \
  --wayland-text-input-version=3
