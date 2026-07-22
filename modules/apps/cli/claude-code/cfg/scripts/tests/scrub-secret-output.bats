#!/usr/bin/env bats
# Regression tests for scrub-secret-output.sh, the PostToolUse hook that redacts
# secret values from a Bash tool's stdout/stderr before the model sees them.
#
# The two failure modes that matter: under-redaction (a real token slips through
# and reaches the transcript) and over-redaction (a git SHA or nix-store hash
# gets mangled, corrupting normal output). Both directions are pinned here. The
# literal-value cases depend on a fixture secrets.json written in setup().

HOOK="${BATS_TEST_DIRNAME}/../scrub-secret-output.sh"

setup() {
  SF="${BATS_TEST_TMPDIR}/secrets.json"
  cat >"$SF" <<'J'
{"aha":{"apiToken":"a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0"},
 "onepassword":{"serviceAccountToken":"ops_eyMOCKFAKEvalue1234567890abcdefghij"},
 "forgejo":{"apiURL":"https://git.srvrs.co","user":"bashfulrobot"}}
J
}

# Print the redacted stdout the hook would hand back (empty if no rewrite).
scrubbed() {
  jq -nc --arg s "$1" '{tool_name:"Bash",tool_response:{stdout:$s,stderr:"",interrupted:false,isImage:false}}' \
    | NIXOS_SECRETS_FILE="$SF" bash "$HOOK" \
    | jq -r '.hookSpecificOutput.updatedToolOutput.stdout // ""'
}

# True when the hook emits no rewrite at all (content was safe).
emits_nothing() {
  local out
  out="$(jq -nc --arg s "$1" '{tool_name:"Bash",tool_response:{stdout:$s,stderr:"",interrupted:false,isImage:false}}' \
    | NIXOS_SECRETS_FILE="$SF" bash "$HOOK")"
  [ -z "$out" ]
}

@test "redacts literal secret values from secrets.json" {
  [[ "$(scrubbed 'the token is a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0 ok')" == *"[REDACTED-SECRET]"* ]]
  [[ "$(scrubbed 'master ops_eyMOCKFAKEvalue1234567890abcdefghij here')" == *"[REDACTED-SECRET]"* ]]
}

@test "redacts known token-shaped prefixes" {
  [[ "$(scrubbed 'xoxc-1234567890-abcdefghijklmnop')" == *"[REDACTED-SLACK-TOKEN]"* ]]
  [[ "$(scrubbed 'xoxd-AbCdEf1234567890xyz')" == *"[REDACTED-SLACK-TOKEN]"* ]]
  [[ "$(scrubbed 'ghp_ABCDEFGHIJ0123456789abcdefghij012345')" == *"[REDACTED-GH-TOKEN]"* ]]
  [[ "$(scrubbed 'github_pat_11ABCDEFG0123456789_abcdefghijklmnop')" == *"[REDACTED-GH-TOKEN]"* ]]
  [[ "$(scrubbed 'glsa_ABCdef0123456789ABCDEFGHIJ012345_ab')" == *"[REDACTED-GRAFANA-TOKEN]"* ]]
  [[ "$(scrubbed 'AIzaSyD1234567890abcdefghijklmnopqrstuv')" == *"[REDACTED-GOOGLE-KEY]"* ]]
  [[ "$(scrubbed 'eyJhbGciOiJIUzI1.eyJzdWIiOiIxMjM0NTY.SflKxwRJSMeKKF2QT4')" == *"[REDACTED-JWT]"* ]]
  [[ "$(scrubbed 'Authorization: Bearer abcdef0123456789ABCDEF0123456789')" == *"[REDACTED-TOKEN]"* ]]
}

@test "preserves the tool_response output shape" {
  run bash -c "jq -nc --arg s 'xoxc-1234567890-abcdefghijklmnop' '{tool_name:\"Bash\",tool_response:{stdout:\$s,stderr:\"\",interrupted:false,isImage:false}}' | NIXOS_SECRETS_FILE='$SF' bash '$HOOK' | jq -c '.hookSpecificOutput.updatedToolOutput|keys'"
  [ "$status" -eq 0 ]
  [ "$output" = '["interrupted","isImage","stderr","stdout"]' ]
}

@test "does not touch git SHAs, nix hashes, or ordinary output" {
  emits_nothing 'commit 5766a986e1c2d3b4a5f60718293a4b5c6d7e8f90 landed'
  emits_nothing '/nix/store/scfggl635j0sn52ar62fw47khf338004-claude-code-2.1.216/bin'
  emits_nothing 'sha256-AbCdEf0123456789hashlikestringbutnotsecret='
  emits_nothing 'just built qbert successfully in 42s'
  emits_nothing 'https://git.srvrs.co/api/v1/repos'
}

@test "ignores non-Bash tool_response (no stdout/stderr)" {
  run bash -c "jq -nc '{tool_name:\"Read\",tool_response:{filePath:\"/x\",content:\"a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0\"}}' | NIXOS_SECRETS_FILE='$SF' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
