#!/usr/bin/env bash
# Tests for ttu_redact.sh. Run: bash ttu_redact.test.sh
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pass=0; fail=0
clean() { # name text  -> expect exit 0
  if printf '%s' "$2" | bash "$here/ttu_redact.sh" >/dev/null 2>&1; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1 (should be clean)"; fail=$((fail+1)); fi; }
dirty() { # name text  -> expect exit 3 AND no value leak on stderr
  err=$(printf '%s' "$2" | bash "$here/ttu_redact.sh" 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 3 ] && ! printf '%s' "$err" | grep -qF "$2"; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1 (rc=$rc, or value leaked)"; fail=$((fail+1)); fi; }

# Legitimate comment content must pass untouched.
clean "prose"     "Christian replied in Aha; confirmed the July date. See thread."
clean "git sha"   "Fixed in commit 5766a986e4b1c0d9f8a7b6c5d4e3f2a1b0c9d8e7 on main."
clean "uuid/org"  "Konnect org f3170a13-482d-4cf6-8121-ae7a185cde8d is active."
clean "sf id"     "Opp 006PJ00000Oct2UYAR closed-won."
clean "hyphen slug"  "task-abcdefghijklmnopqrstuvwxyz needs review"
clean "desk word"    "the desk-abcdefghijklmnopqrstuv sits here"

# Secret shapes must be refused (exit 3), and the value must NOT appear on stderr.
# The provider-shaped fixtures are assembled from fragments at runtime so the
# on-disk source never contains a literal token that trips upstream secret-scanning
# push protection (e.g. GitHub). The value handed to ttu_redact.sh is identical;
# only the file's byte representation is split.
xoxb="xox""b-123456789012-abcdefghijklmnop"      # fake Slack token shape
ghp="gh""p_abcdefghijklmnopqrstuvwxyz0123456789" # fake GitHub PAT shape
skk="s""k-abcdefghijklmnop0123456789"            # fake sk- provider key shape
dirty "slack xoxb"  "token is $xoxb"
dirty "bearer"      "Authorization: Bearer abcdefghijklmnopqrstuvwxyz012345"
dirty "op ref"      "read op://nixerator/todoist/token please"
dirty "github pat"  "$ghp"
dirty "sk key"      "key $skk"

echo "----"; echo "pass=$pass fail=$fail"; [ "$fail" -eq 0 ]
