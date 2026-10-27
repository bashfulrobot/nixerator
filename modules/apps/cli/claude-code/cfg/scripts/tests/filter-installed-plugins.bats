#!/usr/bin/env bats
# Regression tests for filter-installed-plugins.jq, the filter cfg/activation.nix
# runs over the repo's captured plugins/installed_plugins.json before writing it
# to ~/.claude/plugins with stackApply on.
#
# The bug these pin: the captured copy is taken on qbert, and activation used to
# seed it onto every host verbatim. srv therefore got qbert's whole plugin set
# back on every `just remote-rebuild srv`, which is where drift's
# PLUGIN_SHOULD_BE_ABSENT x6 and PLUGIN_UNDECLARED x8 kept coming from after the
# claude-skills `headless` profile (claude-skills #182) declared six absent and
# the eight extras were uninstalled by hand.
#
# The srv id lists below are the real ones from
# claude-stack/resolved/srv.json. They are literals rather than a read of the
# flake input, because the input's store path is not available to bats and the
# repo's cfg/claude-stack/srv.json snapshot is the stale copy stackApply exists
# to replace.

FILTER="${BATS_TEST_DIRNAME}/../filter-installed-plugins.jq"
REPO_RECORDS="${BATS_TEST_DIRNAME}/../../../config/plugins/installed_plugins.json"
REPO_QBERT_SNAPSHOT="${BATS_TEST_DIRNAME}/../../claude-stack/qbert.json"

setup() {
  TMP="$(mktemp -d)"
  RECORDS="$TMP/installed_plugins.json"
  KEEP="$TMP/keep.json"
}

teardown() {
  rm -rf "$TMP"
}

# filter -> filtered document on stdout
filter() {
  jq -f "$FILTER" --slurpfile keep "$KEEP" "$RECORDS"
}

# ids <file> -> sorted plugin ids, one per line
ids() {
  jq -r '.plugins | keys_unsorted[]' "$1" | sort
}

# The six srv declares absent, and the eight srv declares not at all. Both sets
# are present in the qbert-captured repo copy.
srv_absent() {
  printf '%s\n' \
    'commit-commands@claude-plugins-official' \
    'kong-demo-config-generator@claude-skills' \
    'kong-doc-build@kong-skills' \
    'plugin-dev@claude-plugins-official' \
    'security-guidance@claude-plugins-official' \
    'skill-creator@claude-plugins-official'
}

srv_undeclared() {
  printf '%s\n' \
    'cloudflare@claude-skills' \
    'gitops@claude-skills' \
    'kong-cs@claude-skills' \
    'kong-docs-rag@claude-skills' \
    'kong-konnect@claude-skills' \
    'kong-tableau@claude-skills' \
    'security-audit@claude-skills' \
    'semagraph@semagraph'
}

@test "a declared id is kept whole, record array and all" {
  jq -n '{version:2,plugins:{"a@m":[{scope:"user",version:"1"}],"b@m":[{scope:"user",version:"2"}]}}' > "$RECORDS"
  jq -n '["a@m"]' > "$KEEP"
  run filter
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.plugins')" = '{"a@m":[{"scope":"user","version":"1"}]}' ]
}

@test "keys outside .plugins are untouched" {
  jq -n '{version:2,somethingElse:{k:1},plugins:{"a@m":[]}}' > "$RECORDS"
  jq -n '["a@m"]' > "$KEEP"
  run filter
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.version')" = '2' ]
  [ "$(echo "$output" | jq -c '.somethingElse')" = '{"k":1}' ]
}

@test "qbert's keep list keeps every record in the repo copy" {
  # qbert declares all 32 captured ids non-absent, so the filter is the
  # identity there. This is the case that must not regress: a filter that drops
  # anything on qbert would starve the host the record is captured from.
  cp "$REPO_RECORDS" "$RECORDS"
  jq '[.plugins | to_entries[] | select(.value.state != "absent") | .key]' \
    "$REPO_QBERT_SNAPSHOT" > "$KEEP"
  run filter
  [ "$status" -eq 0 ]
  echo "$output" > "$TMP/out.json"
  [ "$(ids "$TMP/out.json")" = "$(ids "$REPO_RECORDS")" ]
}

@test "srv's keep list drops the six absent and the eight undeclared" {
  cp "$REPO_RECORDS" "$RECORDS"
  # Everything in the repo copy except srv's absent and undeclared sets.
  { srv_absent; srv_undeclared; } | sort > "$TMP/drop.txt"
  ids "$REPO_RECORDS" > "$TMP/all.txt"
  comm -23 "$TMP/all.txt" "$TMP/drop.txt" > "$TMP/want.txt"
  jq -R -s 'split("\n") | map(select(length > 0))' "$TMP/want.txt" > "$KEEP"

  run filter
  [ "$status" -eq 0 ]
  echo "$output" > "$TMP/out.json"
  ids "$TMP/out.json" > "$TMP/got.txt"

  [ "$(cat "$TMP/got.txt")" = "$(cat "$TMP/want.txt")" ]
  [ "$(wc -l < "$TMP/got.txt")" -eq 18 ]

  # Named explicitly, so a rename upstream fails this test instead of passing
  # on a coincidental count.
  while read -r id; do
    run jq --arg id "$id" -e '.plugins | has($id)' "$TMP/out.json"
    [ "$status" -ne 0 ]
  done < "$TMP/drop.txt"
}

@test "an empty keep list drops every record and keeps a valid document" {
  jq -n '{version:2,plugins:{"a@m":[{scope:"user"}]}}' > "$RECORDS"
  jq -n '[]' > "$KEEP"
  run filter
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.plugins')" = '{}' ]
  [ "$(echo "$output" | jq -c '.version')" = '2' ]
}

@test "an empty record file stays safe" {
  jq -n '{version:2,plugins:{}}' > "$RECORDS"
  jq -n '["a@m"]' > "$KEEP"
  run filter
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.plugins')" = '{}' ]
}

@test "a document with no .plugins key becomes an empty record set" {
  jq -n '{version:2}' > "$RECORDS"
  jq -n '["a@m"]' > "$KEEP"
  run filter
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.plugins')" = '{}' ]
}

@test "a null .plugins becomes an empty record set" {
  jq -n '{version:2,plugins:null}' > "$RECORDS"
  jq -n '["a@m"]' > "$KEEP"
  run filter
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.plugins')" = '{}' ]
}

@test "a missing keep file leaves \$keep empty and drops every record" {
  # activation always passes the generated file, so this is the defensive path:
  # /dev/null slurps to [], and $keep[0] // [] keeps the filter from erroring.
  jq -n '{version:2,plugins:{"a@m":[]}}' > "$RECORDS"
  run jq -f "$FILTER" --slurpfile keep /dev/null "$RECORDS"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.plugins')" = '{}' ]
}

@test "malformed JSON fails closed" {
  printf 'not json at all' > "$RECORDS"
  jq -n '["a@m"]' > "$KEEP"
  run filter
  [ "$status" -ne 0 ]
}

@test "a JSON value that is not an object fails closed" {
  jq -n '[1,2,3]' > "$RECORDS"
  jq -n '["a@m"]' > "$KEEP"
  run filter
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a JSON object"* ]]
}

@test "the activation write-through leaves the old file in place when the filter fails" {
  # Mirrors the shell cfg/activation.nix runs with stackApply on: build into a
  # temp, mv only on success. A corrupt repo copy must not blank a good
  # deployed record, because Claude Code would then re-install everything.
  dest="$TMP/dest.json"
  jq -n '{version:2,plugins:{"good@m":[{scope:"user"}]}}' > "$dest"
  printf 'not json at all' > "$RECORDS"
  jq -n '["good@m"]' > "$KEEP"

  tmp="$dest.tmp"
  if jq -f "$FILTER" --slurpfile keep "$KEEP" "$RECORDS" > "$tmp"; then
    mv "$tmp" "$dest"
  else
    rm -f "$tmp"
  fi

  [ ! -e "$tmp" ]
  [ "$(jq -c '.plugins' "$dest")" = '{"good@m":[{"scope":"user"}]}' ]
}

@test "the activation write-through replaces the file and keeps mode 0644 on success" {
  dest="$TMP/dest.json"
  jq -n '{version:2,plugins:{"old@m":[]}}' > "$dest"
  chmod 600 "$dest"
  jq -n '{version:2,plugins:{"a@m":[],"b@m":[]}}' > "$RECORDS"
  jq -n '["a@m"]' > "$KEEP"

  tmp="$dest.tmp"
  if jq -f "$FILTER" --slurpfile keep "$KEEP" "$RECORDS" > "$tmp"; then
    chmod 644 "$tmp"
    mv "$tmp" "$dest"
  else
    rm -f "$tmp"
  fi

  [ "$(jq -c '.plugins | keys' "$dest")" = '["a@m"]' ]
  [ "$(stat -c '%a' "$dest")" = "644" ]
}

@test "capture-sync.py has no plugins section, so srv cannot write the record back through it" {
  # The only write-back path for installed_plugins.json is the unguarded block
  # in cfg/fish.nix, which captureInstalledPlugins (default.nix) now gates.
  # capture-sync.py must stay out of it: its sections are snapshot-guarded and
  # would report a conflict on every srv rebuild instead of skipping.
  sync="${BATS_TEST_DIRNAME}/../capture-sync.py"
  [ -f "$sync" ]
  run grep -c 'installed_plugins' "$sync"
  [ "$output" = "0" ]
  # And the section lists it dispatches on name no plugin section.
  run grep -nE '^ *sections = \[' "$sync"
  [ "$status" -eq 0 ]
  [[ "$output" != *plugin* ]]
}

@test "the @HOME_DIR@ substitution survives the filter" {
  # activation pipes sed into jq, so the placeholder must already be expanded in
  # the records the filter keeps.
  jq -n '{version:2,plugins:{"a@m":[{installPath:"@HOME_DIR@/.claude/plugins/cache/m/a/1"}]}}' \
    > "$TMP/src.json"
  jq -n '["a@m"]' > "$KEEP"
  sed 's|@HOME_DIR@|/home/dustin|g' "$TMP/src.json" > "$RECORDS"
  run filter
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.plugins["a@m"][0].installPath')" = "/home/dustin/.claude/plugins/cache/m/a/1" ]
}
