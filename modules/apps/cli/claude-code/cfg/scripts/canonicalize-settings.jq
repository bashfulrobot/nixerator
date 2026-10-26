# Canonicalize the live ~/.claude/settings.json back to the shape of the repo
# source (config/settings.json), so the capture pass in cfg/fish.nix can hand it
# to capture-sync.py's snapshot-guarded settings reconcile (--settings-home,
# cfg/scripts/capture-sync.py's run_settings) as a byte-comparable copy.
#
# The reconcile compares sha256 hashes, so this filter must reproduce the repo
# file byte for byte whenever nothing has diverged. The last test in
# cfg/scripts/tests/canonicalize-settings.bats pins exactly that against the
# real config/settings.json.
#
# Arguments the caller passes:
#
#   --argjson   stack_apply true|false   apps.cli.claude-code.stackApply.enable
#   --slurpfile repo <config/settings.json>   the repo copy, or /dev/null when
#                                             it is absent (then $repo is [])
#
# Lives in its own file rather than inline in cfg/fish.nix so bats runs the real
# filter instead of a copy that drifts from it.

# Keys claude-skills' `settings.force` declares (docs/ai/claude-stack.md there,
# "What is declared, per profile"). apply replaces each one at every rebuild, so
# a captured value is not a repo-side change, it is a value the next rebuild
# reverts. With stackApply off they are repo-owned and stay captured.
#
# $schema, skipAutoPermissionPrompt and pluginConfigs are absent on purpose:
# they are harness- or nixerator-owned and apply never writes them.
def strip_stack_owned:
  if $stack_apply then
    del(
      .model,
      .smallModelOverride,
      .outputStyle,
      .statusLine,
      .attribution,
      .coAuthor,
      .includeCoAuthoredBy,
      .cleanupPeriodDays,
      .tui,
      .env.PATH,
      .env.ANTHROPIC_DEFAULT_OPUS_MODEL,
      .permissions.deny,
      .permissions.defaultMode,
      .permissions.additionalDirectories,
      .agentPushNotifEnabled,
      .awaySummaryEnabled,
      .feedbackDrafts,
      .feedbackSurveyRate,
      .remoteControlEnabled,
      .skipDangerousModePermissionPrompt,
      .skipWorkflowUsageWarning,
      .terminalProgressBarEnabled,
      .todoFeatureEnabled
    )
  else
    .
  end;

# permissions.allow.
#
# stackApply on: the claude-skills manifest owns the list. cfg/activation.nix
# drops the repo block before apply and apply writes the manifest's resolved
# list in its place, so the live list is a derived value like the forced keys
# above, not a captured one. It cannot simply be deleted here, because the repo
# copy still carries its 158-rule block until phase 8 and the two files have to
# hash the same: take the repo copy's block verbatim instead, which makes the
# live list invisible to the reconcile and leaves the repo block untouched.
# A rule approved in a session therefore stops round-tripping into the repo; to
# keep one, run `claude_stack.py promote` in claude-skills (see
# .claude/docs/claude-stack-apply.md).
#
# stackApply off: runtime-owned, as before. cfg/activation.nix only appends the
# manifest's rules (add-only union), so the captured list already contains them
# and the next activation appends nothing.
def repo_owned_allow:
  if $stack_apply then
    (($repo[0] // {}) | .permissions.allow) as $declared
    | if $declared == null then
        del(.permissions.allow)
      else
        .permissions.allow = $declared
      end
  else
    .
  end;

# extraKnownMarketplaces / enabledPlugins: cfg/plugin-config.nix owns them.
# permissions.ask: Nix-owned (activation pins it with stackApply off, the
#   manifest forces it with stackApply on).
# autoMode, skillOverrides: Nix-owned, set at activation from the manifest.
# env.SSH_AUTH_SOCK, env.XDG_RUNTIME_DIR: host-resolved at activation.
del(
  .extraKnownMarketplaces,
  .enabledPlugins,
  .permissions.ask,
  .autoMode,
  .skillOverrides,
  .env.SSH_AUTH_SOCK,
  .env.XDG_RUNTIME_DIR
)
| strip_stack_owned
| repo_owned_allow
# Every Nix-owned hook is injected at activation with its store path, so its
# volatile hash must never be committed. Stripping any hook whose command lives
# under /nix/store covers every current and future injected hook automatically
# and leaves the repo-authored inline `bash -c '...'` rows untouched.
#
# herdr-agent-state is LEGACY: the herdr module is gone, but a host that ran it
# still has hook rows pointing at ~/.claude/hooks/herdr-agent-state.sh, a home
# path the store-path rule misses. Drop the alternation once every host has
# rebuilt at least once.
#
# Any event array left empty after the strip is dropped entirely.
| .hooks = (
    (.hooks // {})
    | map_values(
        map(select((.hooks[0].command // "") | test("/nix/store/|herdr-agent-state") | not))
      )
    | with_entries(select(.value | length > 0))
  )
