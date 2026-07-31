{ lib }:

# Default-off skill surface. Mirrors plugin-config.nix's mkOverlay pattern:
# turns "every installed skill except an always-on baseline" into the
# skillOverrides object merged into settings.json at activation (see
# cfg/activation.nix), and stripped from capture the same way the plugin
# overlay keys are, so Nix -- not a captured runtime edit -- owns the
# default. Per-project opt-in on top of this default is `skill-pick`
# (cfg/scripts/skill-pick.bash), which writes "on" entries into a project's
# .claude/settings.local.json; the settings cascade resolves per skill name,
# local scope falling back to this user-scope default, so an "on" there
# beats the "off" here.
#
# alwaysOn: skills that stay enabled everywhere, no per-project opt-in
# needed. Two reasons a skill earns a spot here, not a hunch:
#   - named directly in ~/.claude/CLAUDE.md's trigger-scoped rules (removing
#     it would leave that rule pointing at nothing): bug-fix-workflow,
#     code-style, merge-conflicts, git-cleanup, rtk-output-compression,
#     send-to-dustin, kong-docs-lookup, curated-knowledge
#   - heavy, cross-project usage confirmed by claude-code doctor (2026-07-30):
#     text-polish, humanizer, commit, github-issue, review-dev,
#     review-security, writing-style, auto, log-github-issue, sfdc,
#     kong-technical-csm, todoist-cli, gws-cli, slack-post
#
# github-issue is listed above for documentation but has no effect here: it
# ships from apps/cli/worktree-flow, not config/skills, so it never appears
# in allNames below and this file never touches it. It stays on by Claude
# Code's own absent-key-means-on default, which is what the baseline wants
# anyway -- harmless, just worth knowing if you go looking for its override.
let
  alwaysOn = [
    "text-polish"
    "humanizer"
    "commit"
    "bug-fix-workflow"
    "code-style"
    "merge-conflicts"
    "git-cleanup"
    "rtk-output-compression"
    "send-to-dustin"
    "kong-docs-lookup"
    "curated-knowledge"
    "github-issue"
    "review-dev"
    "review-security"
    "writing-style"
    "auto"
    "log-github-issue"
    "sfdc"
    "kong-technical-csm"
    "todoist-cli"
    "gws-cli"
    "slack-post"
  ];

  # allNames: every skill name Nix installs into ~/.claude/skills -- the
  # config/skills/* directory listing plus the vendored (symlinked)
  # flake-input skills, which don't live under config/skills.
  mkOverlay =
    {
      configSkillsDir,
      vendoredNames,
    }:
    let
      configNames = builtins.attrNames (
        lib.filterAttrs (_: type: type == "directory") (builtins.readDir configSkillsDir)
      );
      allNames = lib.unique (configNames ++ vendoredNames);
      offNames = lib.subtractLists alwaysOn allNames;
    in
    {
      skillOverrides = lib.genAttrs offNames (_: "off");
    };
in
{
  inherit alwaysOn mkOverlay;
}
