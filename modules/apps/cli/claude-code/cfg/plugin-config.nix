{ lib }:

# Declarative, version-pinned Claude Code plugin surface.
#
# `mkOverlay pluginIds` turns a per-host list of "<plugin>@<marketplace>" ids
# (the `apps.cli.claude-code.plugins` option) into the JSON object merged into
# the deployed ~/.claude/settings.json at activation (see cfg/activation.nix):
# `enabledPlugins` (every id, enabled) and `extraKnownMarketplaces` (only the
# pinned third-party marketplaces actually referenced by the list). Those keys
# are stripped from the captured repo settings.json (cfg/fish.nix) so Nix --
# not the captured runtime state -- owns them. Keeping this a function of the
# plugin list preserves per-host variation (e.g. headless srv runs a smaller
# set than the workstations) while still pinning marketplaces to commit SHAs.
#
# Pinning model: for git-backed marketplaces Claude Code resolves a plugin's
# version from `plugin.json` version > marketplace-entry version > the
# marketplace repo's commit SHA. The third-party plugins here use relative-path
# sources inside their marketplace repo, so pinning the *marketplace* to a SHA
# pins every plugin it ships. Bump a SHA the way you bump flake.lock (find the
# new HEAD with `git -C ~/.claude/plugins/marketplaces/<name> rev-parse origin/main`).
#
# claude-plugins-official is the built-in Anthropic marketplace and is never
# declared. A marketplace is only declared when a plugin from it is enabled, so
# dormant trust grants (e.g. superpowers-marketplace, claude-code-lsps,
# kong-se-skills) never reappear -- superpowers and the LSP plugins all ship
# from claude-plugins-official, and the project's own Nix LSP marketplace
# (nix-lsps) is generated in cfg/lsp-plugins.nix.
let
  # Built-in marketplaces that are always known and must not be declared.
  builtinMarketplaces = [ "claude-plugins-official" ];

  # Active third-party marketplaces, pinned to commit SHAs.
  marketplaceSources = {
    kong-skills.source = {
      source = "github";
      repo = "Kong/kong-skills";
      sha = "fe5c4d1b8f1fb3ee3b44e0124b6dd9cd54ebed22";
    };
    impeccable.source = {
      source = "github";
      repo = "pbakaus/impeccable";
      sha = "e3e22007a974fbb2023d36a3abf643f49dfd1fb3";
    };
    hyperframes.source = {
      source = "github";
      repo = "heygen-com/hyperframes";
      sha = "553688c996408cb33de27ce4573bef6c8cf27454";
    };
  };

  marketplaceOf = pluginId: lib.last (lib.splitString "@" pluginId);

  mkOverlay =
    pluginIds:
    let
      referenced = lib.unique (map marketplaceOf pluginIds);
      # Marketplaces that are neither built-in nor pinned here -- fail loudly
      # rather than silently failing to register them at runtime.
      unknown = lib.filter (
        m: !(lib.elem m builtinMarketplaces) && !(marketplaceSources ? ${m})
      ) referenced;
      neededExtra = lib.filter (m: marketplaceSources ? ${m}) referenced;
    in
    lib.throwIf (unknown != [ ])
      "claude-code plugin-config: plugin(s) reference unknown marketplace(s) ${toString unknown}; add a pinned source to marketplaceSources in cfg/plugin-config.nix"
      {
        extraKnownMarketplaces = lib.genAttrs neededExtra (m: marketplaceSources.${m});
        enabledPlugins = lib.genAttrs pluginIds (_: true);
      };
in
{
  # mkOverlay : [ "name@marketplace" ] -> { extraKnownMarketplaces; enabledPlugins; }
  inherit mkOverlay;
}
