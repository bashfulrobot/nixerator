#!/usr/bin/env bats
# Regression tests for activation-allow.jq, the permissions.allow pass
# cfg/activation.nix runs over ~/.claude/settings.json.
#
# Two modes, one filter. With apps.cli.claude-code.stackApply.enable off the
# manifest's rules are unioned into the live list, add-only, as they always
# were. With it on the block is dropped so claude_stack.py apply, which runs
# after this, is the only writer of the list.

FILTER="${BATS_TEST_DIRNAME}/../activation-allow.jq"

setup() {
  TMP="$(mktemp -d)"
  LIVE="$TMP/settings.json"
  DECL="$TMP/decl.json"
}

teardown() {
  rm -rf "$TMP"
}

# pass <true|false> [input-file] -> filtered settings on stdout
pass() {
  jq -f "$FILTER" --argjson stack_apply "$1" --slurpfile decl "$DECL" "${2:-$LIVE}"
}

@test "off: declared rules are appended, live order kept" {
  jq -n '{permissions:{allow:["Read","Bash(git status)"]}}' > "$LIVE"
  jq -n '["Bash(just *)","Read"]' > "$DECL"
  run pass false
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.permissions.allow')" = '["Read","Bash(git status)","Bash(just *)"]' ]
}

@test "off: the union is idempotent" {
  jq -n '{permissions:{allow:["Read"]}}' > "$LIVE"
  jq -n '["Bash(just *)"]' > "$DECL"
  pass false > "$TMP/once.json"
  run pass false "$TMP/once.json"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.permissions.allow')" = '["Read","Bash(just *)"]' ]
}

@test "off: a legacy X(a:*) live rule is not duplicated by X(a *)" {
  jq -n '{permissions:{allow:["Bash(just:*)"]}}' > "$LIVE"
  jq -n '["Bash(just *)"]' > "$DECL"
  run pass false
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.permissions.allow')" = '["Bash(just:*)"]' ]
}

@test "off: a missing allow key becomes the declared list" {
  jq -n '{permissions:{deny:["Read(./.env)"]}}' > "$LIVE"
  jq -n '["Read"]' > "$DECL"
  run pass false
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.permissions.allow')" = '["Read"]' ]
}

@test "on: the live allow block is dropped and nothing else is touched" {
  jq -n '{model:"opus", permissions:{allow:["Read","Edit","Bash(rm *)"], deny:["Read(./.env)"]}}' > "$LIVE"
  jq -n '["Read"]' > "$DECL"
  run pass true
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.permissions | has("allow")')" = "false" ]
  [ "$(echo "$output" | jq -c '.permissions.deny')" = '["Read(./.env)"]' ]
  [ "$(echo "$output" | jq -r '.model')" = "opus" ]
}

@test "on: the drop is idempotent and ignores the declared list" {
  jq -n '{permissions:{allow:["Read"]}}' > "$LIVE"
  jq -n '["Read","Bash(just *)"]' > "$DECL"
  pass true > "$TMP/once.json"
  run pass true "$TMP/once.json"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.permissions')" = '{}' ]
}
