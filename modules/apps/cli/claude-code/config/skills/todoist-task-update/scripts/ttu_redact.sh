#!/usr/bin/env bash
# ttu_redact.sh — refuse secret-shaped content before it is written to a comment
# or the cache. stdin text → exit 0 (clean) or exit 3 with a NON-SECRET class name
# (never the value). Known credential shapes only, to avoid SHA/UUID false-positives.
case $- in *x*)
  echo "refusing to run under set -x" >&2
  exit 2
  ;;
esac
set -uo pipefail
blob="$(cat)"
# "pattern|human class name" — the class name is safe to print; the value is not.
checks=(
  '(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{16,}|provider key (sk-)'
  'xox[bpasr]-[A-Za-z0-9-]{10,}|Slack token (xox*)'
  'gh[pousr]_[A-Za-z0-9]{20,}|GitHub token (gh*_)'
  'AKIA[0-9A-Z]{16}|AWS access key id'
  'AIza[0-9A-Za-z_-]{20,}|Google API key'
  'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+|JWT'
  'Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|Bearer auth header'
  'op://[^[:space:]]+|1Password op:// reference'
)
for entry in "${checks[@]}"; do
  pat="${entry%|*}"
  label="${entry##*|}"
  if printf '%s' "$blob" | grep -qE "$pat"; then
    echo "refusing write: secret-shaped content — $label" >&2
    exit 3
  fi
done
exit 0
