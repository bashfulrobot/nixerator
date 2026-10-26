#!/usr/bin/env bats
# Regression tests for canonicalize-settings.jq, the filter cfg/fish.nix runs
# over the live ~/.claude/settings.json before handing it to capture-sync.py's
# settings reconcile (--settings-home). The filter's contract: the canonicalized
# live file must equal config/settings.json byte for byte when nothing has
# diverged, because the reconcile compares sha256 hashes.
#
# The case these pin: with apps.cli.claude-code.stackApply.enable on,
# permissions.allow belongs to the claude-skills manifest. apply replaces the
# live list at every rebuild, so a captured live list is not a repo change, it
# is a value the next rebuild reverts. The filter therefore takes the allow
# block from the repo copy and ignores the live one. With stackApply off the
# live list is still captured, unchanged.

FILTER="${BATS_TEST_DIRNAME}/../canonicalize-settings.jq"
REPO_SETTINGS="${BATS_TEST_DIRNAME}/../../../config/settings.json"

setup() {
  TMP="$(mktemp -d)"
  LIVE="$TMP/live.json"
  REPO="$TMP/repo.json"
}

teardown() {
  rm -rf "$TMP"
}

# canon <true|false> <repo-file-or-/dev/null> -> canonicalized live file on stdout
canon() {
  jq -f "$FILTER" --argjson stack_apply "$1" --slurpfile repo "$2" "$LIVE"
}

@test "stackApply on: the live allow list is replaced by the repo copy's" {
  jq -n '{permissions:{allow:["Bash(live *)","Read"]}}' > "$LIVE"
  jq -n '{permissions:{allow:["Bash(repo *)"]}}' > "$REPO"
  run canon true "$REPO"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.permissions.allow')" = '["Bash(repo *)"]' ]
}

@test "stackApply on: a live rule approved in a session is never captured" {
  # The repo copy and the live file agree except for one /permissions approval.
  # Canonicalized, the two must be identical, so the reconcile sees a noop.
  jq -n '{permissions:{allow:["Read","Edit"]}, hooks:{Stop:[{hooks:[{command:"bash -c true"}]}]}}' > "$REPO"
  jq -n '{permissions:{allow:["Read","Edit","Bash(rm -rf /tmp/x)"]}, hooks:{Stop:[{hooks:[{command:"bash -c true"}]}]}}' > "$LIVE"
  run canon true "$REPO"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -S .)" = "$(jq -S . "$REPO")" ]
}

@test "stackApply off: the live allow list is captured unchanged" {
  jq -n '{permissions:{allow:["Read","Edit","Bash(rm -rf /tmp/x)"]}}' > "$LIVE"
  jq -n '{permissions:{allow:["Read","Edit"]}}' > "$REPO"
  run canon false "$REPO"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.permissions.allow')" = '["Read","Edit","Bash(rm -rf /tmp/x)"]' ]
}

@test "stackApply on with no repo settings.json drops the allow key" {
  jq -n '{permissions:{allow:["Read"]}}' > "$LIVE"
  run canon true /dev/null
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.permissions | has("allow")')" = "false" ]
}

@test "stackApply on drops the manifest-owned keys" {
  jq -n '{model:"opus", statusLine:{type:"command"}, tui:{x:1},
          env:{PATH:"/nix/store/x/bin", ENABLE_STOP_REVIEW:"0"},
          permissions:{deny:["Read(./.env)"], ask:["Bash(sudo *)"],
                       defaultMode:"acceptEdits", additionalDirectories:["/x"],
                       allow:["Read"]},
          todoFeatureEnabled:true}' > "$LIVE"
  jq -n '{permissions:{allow:["Read"]}}' > "$REPO"
  run canon true "$REPO"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c 'keys_unsorted')" = '["env","permissions","hooks"]' ]
  [ "$(echo "$output" | jq -c '.env')" = '{"ENABLE_STOP_REVIEW":"0"}' ]
  [ "$(echo "$output" | jq -c '.permissions')" = '{"allow":["Read"]}' ]
}

@test "stackApply off keeps the manifest-owned keys" {
  jq -n '{model:"opus", todoFeatureEnabled:true,
          permissions:{deny:["Read(./.env)"], ask:["Bash(sudo *)"], allow:["Read"]}}' > "$LIVE"
  jq -n '{permissions:{allow:["Read"]}}' > "$REPO"
  run canon false "$REPO"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.model')" = "opus" ]
  [ "$(echo "$output" | jq -r '.todoFeatureEnabled')" = "true" ]
  [ "$(echo "$output" | jq -c '.permissions.deny')" = '["Read(./.env)"]' ]
  # permissions.ask is Nix-owned in both modes.
  [ "$(echo "$output" | jq -c '.permissions | has("ask")')" = "false" ]
}

@test "store-path and herdr hooks are stripped in both modes, empty events dropped" {
  jq -n '{hooks:{PostToolUse:[{hooks:[{command:"bash -c true"}]},
                              {hooks:[{command:"/nix/store/abc/bin/guard"}]}],
                 SessionStart:[{hooks:[{command:"/nix/store/def/bin/reminders"}]}],
                 PreToolUse:[{hooks:[{command:"/home/dustin/.claude/hooks/herdr-agent-state.sh"}]}]}}' > "$LIVE"
  jq -n '{}' > "$REPO"
  for mode in true false; do
    run canon "$mode" "$REPO"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -c '.hooks | keys_unsorted')" = '["PostToolUse"]' ]
    [ "$(echo "$output" | jq -c '.hooks.PostToolUse | length')" = "1" ]
  done
}

@test "the real config/settings.json is a fixpoint through activation and apply" {
  # Simulate what a stackApply-on host's ~/.claude/settings.json looks like
  # after cfg/activation.nix and claude_stack.py apply have run over the repo
  # copy: the Nix-owned keys merged in, the manifest-owned keys forced,
  # permissions.allow replaced by the manifest's resolved list, and a Nix-built
  # hook appended with its store path. Canonicalizing that must reproduce the
  # repo file exactly, or every capture reports a phantom change.
  jq '.extraKnownMarketplaces = {"claude-skills":{"source":"x"}}
      | .enabledPlugins = {"dk@claude-skills":true}
      | .autoMode = {soft_deny:["Bash(rm *)"]}
      | .skillOverrides = {foo:"off"}
      | .env.SSH_AUTH_SOCK = "/run/user/1000/gcr/ssh"
      | .env.XDG_RUNTIME_DIR = "/run/user/1000"
      | .env.PATH = "/nix/store/zzz/bin"
      | .env.ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-4"
      | .model = "opusplan"
      | .smallModelOverride = "haiku"
      | .outputStyle = "dustin"
      | .statusLine = {type:"command", command:"/nix/store/yyy/bin/claude-statusline"}
      | .attribution = false
      | .coAuthor = false
      | .includeCoAuthoredBy = false
      | .cleanupPeriodDays = 60
      | .tui = {theme:"dark"}
      | .agentPushNotifEnabled = false
      | .awaySummaryEnabled = false
      | .feedbackDrafts = false
      | .feedbackSurveyRate = 0
      | .remoteControlEnabled = true
      | .skipDangerousModePermissionPrompt = true
      | .skipWorkflowUsageWarning = true
      | .terminalProgressBarEnabled = true
      | .todoFeatureEnabled = true
      | .permissions.deny = ["Read(./.env)"]
      | .permissions.ask = ["Bash(sudo *)"]
      | .permissions.defaultMode = "acceptEdits"
      | .permissions.additionalDirectories = ["/home/dustin/git"]
      | .permissions.allow = ["Read","Bash(just *)"]
      | .hooks.PostToolUse += [{matcher:"Bash", hooks:[{type:"command", command:"/nix/store/www/bin/claude-guard-raw-nix"}]}]
      | .hooks.PreCompact = [{hooks:[{type:"command", command:"/nix/store/vvv/bin/claude-precompact-checkpoint"}]}]' \
    "$REPO_SETTINGS" > "$LIVE"
  run canon true "$REPO_SETTINGS"
  [ "$status" -eq 0 ]
  echo "$output" > "$TMP/canon.json"
  run diff "$REPO_SETTINGS" "$TMP/canon.json"
  [ "$status" -eq 0 ]
}
