{ lib, stackHost }:

# Declarative, version-pinned Claude Code plugin surface, derived from the
# claude-stack manifest snapshot.
#
# Source of truth: bashfulrobot/claude-skills, claude-stack/claude-stack.json
# (schema: docs/ai/claude-stack.md there). Its resolver writes one file per
# host to claude-stack/resolved/<host>.json; the bump script
# (cfg/scripts/bump-plugin-marketplace-sha.sh) copies qbert.json and srv.json
# into ./claude-stack/ here, at the same claude-skills sha it pins below, in
# the same commit. claude-skills is private, so there is no flake input; the
# committed snapshot is what `builtins.fromJSON` reads. Which host's file
# applies is `apps.cli.claude-code.stackHost` (defaults to the hostname).
#
# `mkOverlay stack` turns that file into the JSON object merged into the
# deployed ~/.claude/settings.json at activation (cfg/activation.nix):
#   - `enabledPlugins`: state enabled -> true, disabled -> false, absent ->
#     dropped (an absent plugin must not appear in settings.json at all).
#   - `extraKnownMarketplaces`: the non-builtin marketplaces the manifest
#     resolved for this host (it already limits them to marketplaces a
#     non-absent plugin references), each pinned to its manifest sha.
# Both keys are stripped from the captured repo settings.json (cfg/fish.nix),
# so Nix, not captured runtime state, owns them.
#
# Marketplaces and plugins are no longer declared in this file. To add, drop or
# re-pin one, edit claude-stack.json in claude-skills, run `just stack-resolve`
# there, merge, then re-bump (`just bump-claude-skills`). Rationale for each
# marketplace/plugin (licence, review-before-bump, why dropped) lives in the
# manifest's `notes`/`review` fields and in .claude/docs/claude-plugins.md.
#
# Pinning model: for git-backed marketplaces Claude Code resolves a plugin's
# version from `plugin.json` version > marketplace-entry version > the
# marketplace repo's commit SHA, and the third-party plugins use relative-path
# sources inside their marketplace repo, so pinning the *marketplace* to a SHA
# pins every plugin it ships. The nix-lsps marketplace is generated locally in
# cfg/lsp-plugins.nix and is not part of the manifest.
let
  # Built-in marketplaces that are always known and must not be declared.
  builtinMarketplaces = [ "claude-plugins-official" ];

  # Marketplaces the manifest marks `selfPin: true` carry no sha of their own;
  # their sha comes from here. Only claude-skills (the manifest's own repo)
  # qualifies. Bumped by `just upgrade` / `just quiet-upgrade` /
  # `just bump-claude-skills` (cfg/scripts/bump-plugin-marketplace-sha.sh),
  # which rewrites the sha line below AND refreshes the ./claude-stack snapshot
  # at that same sha. It's this user's own repo, so it doesn't need the
  # re-read-before-bump treatment the manifest's `review` entries ask for.
  selfPins = {
    claude-skills.source = {
      source = "github";
      repo = "bashfulrobot/claude-skills";
      sha = "2c695da736b77306e5b2daf922886482530b822a";
    };
  };

  snapshotFile = ./claude-stack + "/${stackHost}.json";

  stack =
    lib.throwIfNot (builtins.pathExists snapshotFile)
      "claude-code plugin-config: no claude-stack snapshot for host '${stackHost}' (${toString snapshotFile}); set apps.cli.claude-code.stackHost to qbert or srv, or run cfg/scripts/bump-plugin-marketplace-sha.sh claude-skills bashfulrobot/claude-skills"
      (builtins.fromJSON (builtins.readFile snapshotFile));

  marketplaceOf = pluginId: lib.last (lib.splitString "@" pluginId);

  # Manifest marketplace entry -> the settings.json extraKnownMarketplaces
  # value. `{source, sha}` pins directly; `selfPin` takes the sha from selfPins.
  mkMarketplace =
    name: m:
    if m ? sha then
      {
        source = m.source // {
          inherit (m) sha;
        };
      }
    else if (m.selfPin or false) && selfPins ? ${name} then
      selfPins.${name}
    else
      throw "claude-code plugin-config: marketplace '${name}' has no sha and no selfPins entry in cfg/plugin-config.nix";

  mkOverlay =
    stack:
    let
      verOk =
        lib.throwIf ((stack.schemaVersion or 0) != 1)
          "claude-code plugin-config: claude-stack snapshot schemaVersion is not 1; update cfg/plugin-config.nix for the new schema"
          true;

      active = lib.filterAttrs (_: p: p.state != "absent") stack.plugins;
      marketplaces = lib.filterAttrs (_: m: !(m.builtin or false)) stack.marketplaces;
      referenced = lib.unique (map marketplaceOf (lib.attrNames active));
      # Referenced by a live plugin but neither built-in nor in the manifest's
      # resolved marketplaces: fail loudly rather than silently not registering.
      unknown = lib.filter (m: !(lib.elem m builtinMarketplaces) && !(marketplaces ? ${m})) referenced;
    in
    assert verOk;
    lib.throwIf (unknown != [ ])
      "claude-code plugin-config: plugin(s) reference unknown marketplace(s) ${toString unknown}; fix claude-stack.json in claude-skills and re-bump the snapshot"
      {
        extraKnownMarketplaces = lib.mapAttrs mkMarketplace marketplaces;
        enabledPlugins = lib.mapAttrs (_: p: p.state == "enabled") active;
      };

  # Ids of plugins this host enables (disabled and absent excluded). Used for
  # plugin-gated extras (hyperframes deps).
  enabledIds = stack: lib.attrNames (lib.filterAttrs (_: p: p.state == "enabled") stack.plugins);
in
{
  inherit stack mkOverlay enabledIds;
  # For this host's snapshot, ready for default.nix.
  overlay = mkOverlay stack;
  # permissions.allow rules the manifest declares for this host (already
  # normalised to `X(a *)` and deduplicated by the resolver). NOT part of the
  # overlay: activation unions them into settings.json add-only
  # (cfg/activation.nix), it never overwrites the key.
  permissionsAllow = stack.permissions.allow or [ ];
  enabled = enabledIds stack;
}
