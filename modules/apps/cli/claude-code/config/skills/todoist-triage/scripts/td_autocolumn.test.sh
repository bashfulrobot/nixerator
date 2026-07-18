#!/usr/bin/env bash
# Tests for td_autocolumn.sh column_for_ballowner(). Run: bash td_autocolumn.test.sh
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TD_AUTOCOLUMN_LIB=1 source "$here/td_autocolumn.sh"

pass=0; fail=0
eq() { if [ "$3" = "$2" ]; then echo "PASS: $1"; pass=$((pass+1));
  else echo "FAIL: $1 (want=[$2] got=[$3])"; fail=$((fail+1)); fi; }

eq "customer"   "Waiting Customer"   "$(column_for_ballowner customer)"
eq "internal"   "Waiting Internal"   "$(column_for_ballowner internal)"
eq "me"         "Needs Action"       "$(column_for_ballowner me)"
eq "validation" "Waiting Validation" "$(column_for_ballowner validation)"
eq "unknown"    ""                   "$(column_for_ballowner unknown)"
eq "junk"       ""                   "$(column_for_ballowner wat)"

echo "----"; echo "pass=$pass fail=$fail"; [ "$fail" -eq 0 ]
