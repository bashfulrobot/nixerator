#!/usr/bin/env bash
# Tests for activity-cache.sh. Run: just test-activity-cache (needs GNU stat
# and touch, jq).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! stat -c %Y "$here" > /dev/null 2>&1; then
  echo 'skipped: needs GNU stat (run: just test-activity-cache)'
  exit 0
fi
fails=0
check() {
  if [[ "$2" == "$3" ]]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s (want %s, got %s)\n' "$1" "$3" "$2"
    fails=$((fails + 1))
  fi
}

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
umask 077
# shellcheck source=activity-cache.sh
source "$here/activity-cache.sh"

cache=$dir/activity-2026-10-01.json
last='{"t1":"2026-10-30T10:00:00Z"}'
marks='{"t2":"2026-10-29T09:00:00Z"}'

check "missing file is not fresh" "$(activity_cache_fresh "$cache" 1800 && echo fresh || echo stale)" "stale"

activity_cache_write "$dir" "$cache" "$last" "$marks"
check "written file is fresh" "$(activity_cache_fresh "$cache" 1800 && echo fresh || echo stale)" "fresh"
check "mode is 0600" "$(stat -c %a "$cache")" "600"
check "content round trips" "$(jq -c . "$cache")" '{"last":{"t1":"2026-10-30T10:00:00Z"},"markers":{"t2":"2026-10-29T09:00:00Z"}}'
check "no temp file left behind" "$(find "$dir" -name '.activity.*' | wc -l | tr -d ' ')" "0"

touch -d '31 minutes ago' "$cache"
check "31 minute old file is stale at a 30 minute TTL" "$(activity_cache_fresh "$cache" 1800 && echo fresh || echo stale)" "stale"
touch -d '29 minutes ago' "$cache"
check "29 minute old file is fresh at a 30 minute TTL" "$(activity_cache_fresh "$cache" 1800 && echo fresh || echo stale)" "fresh"

echo 'not json' > "$cache"
check "corrupt file is stale" "$(activity_cache_fresh "$cache" 1800 && echo fresh || echo stale)" "stale"
echo '{"last":{"t1":7},"markers":{}}' > "$cache"
check "non-string value is stale" "$(activity_cache_fresh "$cache" 1800 && echo fresh || echo stale)" "stale"
echo '{"last":{"t1":"soon"},"markers":{}}' > "$cache"
check "non-date string is stale" "$(activity_cache_fresh "$cache" 1800 && echo fresh || echo stale)" "stale"
echo '{"last":[],"markers":{}}' > "$cache"
check "wrong container type is stale" "$(activity_cache_fresh "$cache" 1800 && echo fresh || echo stale)" "stale"

activity_cache_write "$dir" "$cache" "$last" "$marks"
printf 't3\nt4\n' > "$dir/ids"
activity_cache_add_flags "$dir" "$cache" "$dir/ids" "2026-11-02T06:00:00Z"
check "flags land in markers" "$(jq -c '.markers' "$cache")" '{"t2":"2026-10-29T09:00:00Z","t3":"2026-11-02T06:00:00Z","t4":"2026-11-02T06:00:00Z"}'
check "flags keep last untouched" "$(jq -c '.last' "$cache")" "$last"
check "cache stays fresh after add_flags" "$(activity_cache_fresh "$cache" 1800 && echo fresh || echo stale)" "fresh"

: > "$dir/none"
activity_cache_add_flags "$dir" "$cache" "$dir/none" "2026-11-02T07:00:00Z"
check "empty id file changes nothing" "$(jq -c '.markers | length' "$cache")" "3"
activity_cache_add_flags "$dir" "$dir/absent.json" "$dir/ids" "2026-11-02T07:00:00Z"
check "no cache file is not an error and creates nothing" "$([ -e "$dir/absent.json" ] && echo made || echo none)" "none"

# Prune removes caches over 3 hours old and keeps newer ones.
old=$dir/activity-2026-09-01.json
activity_cache_write "$dir" "$old" '{}' '{}'
touch -d '4 hours ago' "$old"
activity_cache_prune "$dir"
check "prune removes the 4 hour old cache" "$([ -e "$old" ] && echo kept || echo gone)" "gone"
check "prune keeps the fresh cache" "$([ -e "$cache" ] && echo kept || echo gone)" "kept"

if [ "$fails" -gt 0 ]; then
  printf '%s failed\n' "$fails"
  exit 1
fi
printf 'all passed\n'
