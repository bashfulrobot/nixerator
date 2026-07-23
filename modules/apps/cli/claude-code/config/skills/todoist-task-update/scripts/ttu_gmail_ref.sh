#!/usr/bin/env bash
# ttu_gmail_ref.sh — classify a Gmail web URL into {shape, id}.
# Pure: arg in, JSON out, no network. Lets the worker decide whether a Gmail
# breadcrumb resolves to one specific thread (shape thread|message, id set) or
# only to a mailbox view (shape label|search|none, id empty) that forces the
# domain-scoped fallback search.
#
# shape:
#   thread   — ?th=<hex> classic permalink; the Gmail API thread id (resolvable)
#   message  — #<view>/<id> web-UI message permalink (best-effort resolvable:
#              the web-UI id and the API id do not always match, so the worker
#              attempts resolution and falls back on error)
#   label    — #label/<name>; no single thread
#   search   — #search/<query>; no single thread
#   none     — bare view (#inbox, #starred, ...) or no usable fragment
case $- in *x*)
  echo "refusing to run under set -x" >&2
  exit 2
  ;;
esac
set -uo pipefail
url="${1:-}"
[ -n "$url" ] || {
  echo "usage: ttu_gmail_ref.sh <gmail-url>" >&2
  exit 2
}
case "$url" in
  *mail.google.com* | *mail.googlemail.com*) ;;
  *)
    echo "not a gmail url: $url" >&2
    exit 2
    ;;
esac

emit() { jq -n --arg s "$1" --arg i "$2" '{shape:$s, id:$i}'; }
# A Gmail message/thread id: a long base64url-ish token. A human label name
# ("Kong-Health-Equity") also matches this, so only trust it in a slot that
# only ever holds an id (segment after the view, or after a label/search name).
is_id() { printf '%s' "${1:-}" | grep -qE '^[A-Za-z0-9_-]{10,}$'; }

# 1. Classic ?th=<hex> permalink wins: it is the Gmail API thread id.
th=$(printf '%s' "$url" | grep -oE '[?&]th=[0-9a-fA-F]+' | head -1 | sed -E 's/.*th=//')
if [ -n "$th" ]; then
  emit thread "$th"
  exit 0
fi

# 2. Fragment shapes. No fragment at all → nothing to follow.
case "$url" in
  *"#"*) frag="${url#*#}" ;;
  *)
    emit none ""
    exit 0
    ;;
esac
frag="${frag%%\?*}" # drop any trailing query on the fragment

# Split the fragment on '/'. Gmail encodes a nested label's own slash as %2F,
# so a literal '/' always separates view / name / id, never label internals.
IFS='/' read -r view seg2 seg3 _rest <<<"$frag"

case "$view" in
  label | search)
    # #label/<name>/<id> or #search/<query>/<id>: the id, if any, is segment 3.
    # Opening a conversation inside a label or search view is the common case,
    # so the exact-thread id lives here, not on the domain-search fallback.
    if is_id "$seg3"; then
      emit message "$seg3"
    elif [ "$view" = label ]; then
      emit label ""
    else
      emit search ""
    fi
    ;;
  "$frag")
    # No '/', so a bare view (inbox, starred, imp, sent, ...) with no id.
    emit none ""
    ;;
  *)
    # #<view>/<id>: the id, if any, is segment 2.
    if is_id "$seg2"; then
      emit message "$seg2"
    else
      emit none ""
    fi
    ;;
esac
