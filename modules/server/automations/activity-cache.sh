# Shared Todoist activity-feed cache for the td-query jobs. Read into the job
# script by default.nix after td-lib.sh, so it carries no shebang and no `set`
# line. Needs jq, stat (GNU) and find.
#
# One file per lookback date, activity-<since>.json in the state directory:
#   {"last": {"<taskId>": "<latest event>"}, "markers": {"<taskId>": "<latest idle flag>"}}
# Mode 0600 (the caller sets umask 077), written by rename so a reader never sees
# half a file, and fresh for a caller-chosen number of seconds.

# Seconds since the file changed, or a huge number when it is missing.
activity_cache_age() {
  if [ -f "$1" ]; then
    echo $(( $(date +%s) - $(stat -c %Y "$1") ))
  else
    echo 999999999
  fi
}

# True when the file is younger than $2 seconds and has the expected shape: two
# objects whose values are all ISO date strings. Anything else is refetched.
activity_cache_fresh() {
  local age
  age=$(activity_cache_age "$1")
  [ "$age" -lt "$2" ] || return 1
  jq -e '(.last | type) == "object" and (.markers | type) == "object" and ([.last[], .markers[]] | all(type == "string" and test("^[0-9]{4}-")))' "$1" > /dev/null 2>&1
}

# activity_cache_write <state_dir> <file> <last json> <markers json>
activity_cache_write() {
  local tmp
  tmp=$(mktemp -p "$1" .activity.XXXXXX)
  jq -nc --argjson last "$3" --argjson markers "$4" '{last: $last, markers: $markers}' > "$tmp"
  mv "$tmp" "$2"
}

# Records new idle flags, so a job that starts later in the window does not
# comment on the same tasks again. activity_cache_add_flags <state_dir> <file>
# <file of task ids, one per line> <ISO time>. No cache file, nothing to do.
activity_cache_add_flags() {
  local tmp
  [ -s "$3" ] && [ -f "$2" ] || return 0
  tmp=$(mktemp -p "$1" .activity.XXXXXX)
  if jq --rawfile ids "$3" --arg at "$4" '.markers += ($ids | split("\n") | map(select(. != "") | {key: ., value: $at}) | from_entries)' "$2" > "$tmp"; then
    mv "$tmp" "$2"
  else
    rm -f "$tmp"
  fi
}

# Deletes caches older than 3 hours, so a changed idleDays leaves nothing behind.
activity_cache_prune() {
  find "$1" -maxdepth 1 -name 'activity-*.json' -mmin +180 -delete
}
