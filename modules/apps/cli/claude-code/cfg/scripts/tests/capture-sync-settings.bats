#!/usr/bin/env bats
# Regression tests for capture-sync.py's settings.json reconcile (--settings-home
# / --settings-repo). settings.json is special: the "home" side is a DERIVED file
# (activation injects store-path hooks + the plugin overlay + the ask list), so
# the caller hands capture-sync a CANONICALIZED copy of home, and capture-sync
# runs a capture-ONLY, snapshot-guarded 3-way that never writes the home side
# (activation owns it).
#
# The bug these pin: the old capture was an UNCONDITIONAL home -> repo copy, so a
# pre-rebuild capture wrote a stale home over a freshly-edited repo, reverting any
# repo-only settings.json change before the rebuild even ran. The "keep-repo" case
# below is that exact scenario and must NOT clobber the repo.

SYNC="${BATS_TEST_DIRNAME}/../capture-sync.py"

setup() {
  TMP="$(mktemp -d)"
  HOME_FILE="$TMP/home.json"   # canonicalized home (what the fish wrapper produces)
  REPO_FILE="$TMP/repo.json"   # repo config/settings.json
  STATE="$TMP/state.json"
}

teardown() {
  rm -rf "$TMP"
}

# Run the settings reconcile; prints the chosen action for settings.json and
# returns capture-sync's exit status. Use via `run run_settings` so bats captures
# both $status (the python exit code) and $output (the action).
run_settings() {
  local out status
  out="$(python3 "$SYNC" \
    --state-file "$STATE" \
    --home-root "$TMP" --repo-root "$TMP" \
    --section none \
    --settings-home "$HOME_FILE" \
    --settings-repo "$REPO_FILE" 2>/dev/null)"
  status=$?
  echo "$out" | jq -r '.actions[] | select(.key=="settings.json") | .action'
  return $status
}

# Seed the snapshot file with a given sha for settings.json.
seed_snapshot() {
  jq -n --arg h "$1" '{version:1, files:{"settings.json":$h}}' > "$STATE"
}

sha() { sha256sum "$1" | cut -d' ' -f1; }

@test "first run with no snapshot seeds baseline from repo, never clobbers" {
  echo '{"a":1}' > "$HOME_FILE"
  echo '{"a":2}' > "$REPO_FILE"   # home != repo, but no snapshot yet
  run run_settings
  [ "$status" -eq 0 ]
  [ "$output" = "seed" ]
  # repo is untouched
  run jq -r '.a' "$REPO_FILE"
  [ "$output" = "2" ]
  # snapshot now records repo's hash
  run jq -r '.files["settings.json"]' "$STATE"
  [ "$output" = "$(sha "$REPO_FILE")" ]
}

@test "in sync is a noop" {
  echo '{"a":1}' > "$HOME_FILE"
  echo '{"a":1}' > "$REPO_FILE"
  seed_snapshot "$(sha "$REPO_FILE")"
  run run_settings
  [ "$status" -eq 0 ]
  [ "$output" = "noop" ]
}

@test "home edited live is captured to repo" {
  # snapshot == repo, home diverged -> a real /permissions-style live edit
  echo '{"allow":["x","y"]}' > "$REPO_FILE"
  seed_snapshot "$(sha "$REPO_FILE")"
  echo '{"allow":["x","y","z"]}' > "$HOME_FILE"
  run run_settings
  [ "$status" -eq 0 ]
  [ "$output" = "capture" ]
  # repo now matches home
  run jq -r '.allow | length' "$REPO_FILE"
  [ "$output" = "3" ]
}

@test "repo edited (PR/merge) with stale home is NOT clobbered" {
  # This is the reverted-hardening bug. snapshot == home (nothing captured since),
  # repo moved ahead via a merge. The stale home must NOT overwrite the repo.
  echo '{"deny":["a"]}' > "$HOME_FILE"
  seed_snapshot "$(sha "$HOME_FILE")"          # snapshot tracks the old home==old repo
  echo '{"deny":["a","b","c","d"]}' > "$REPO_FILE"   # repo edited in a PR
  run run_settings
  [ "$status" -eq 0 ]
  [ "$output" = "keep-repo" ]
  # repo edit survives untouched
  run jq -r '.deny | length' "$REPO_FILE"
  [ "$output" = "4" ]
  # snapshot advances to the repo so the next run is a clean noop once home catches up
  run jq -r '.files["settings.json"]' "$STATE"
  [ "$output" = "$(sha "$REPO_FILE")" ]
}

@test "both sides diverged is a conflict and writes nothing" {
  echo '{"v":"home"}' > "$HOME_FILE"
  echo '{"v":"repo"}' > "$REPO_FILE"
  seed_snapshot "deadbeef"   # snapshot matches neither
  run run_settings
  [ "$status" -ne 0 ]
  [ "$output" = "conflict" ]
  # neither side rewritten
  run jq -r '.v' "$REPO_FILE"
  [ "$output" = "repo" ]
  run jq -r '.v' "$HOME_FILE"
  [ "$output" = "home" ]
}
