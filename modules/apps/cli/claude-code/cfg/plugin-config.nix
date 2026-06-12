{ pkgs }:

# Declarative, version-pinned Claude Code plugin surface.
#
# This file is the single source of truth for which marketplaces are trusted
# and which plugins are enabled. It is merged into the deployed
# ~/.claude/settings.json at activation (see cfg/activation.nix) as the
# `extraKnownMarketplaces` and `enabledPlugins` keys, and those two keys are
# stripped from the captured repo settings.json (see cfg/fish.nix) so Nix --
# not the captured runtime state -- owns them. This replaces the older flow
# that captured installed_plugins.json / known_marketplaces.json from runtime
# (those float on whatever was last installed; this pins to commit SHAs).
#
# Pinning model: for git-backed marketplaces, Claude Code resolves a plugin's
# version from `plugin.json` version > marketplace-entry version > the
# marketplace repo's commit SHA. The kong-skills plugins use relative-path
# sources inside the marketplace repo, so pinning the *marketplace* to a SHA
# pins every plugin it ships. Bump a SHA the way you bump flake.lock.
#
# claude-plugins-official is the built-in Anthropic marketplace and MUST NOT be
# declared here -- it is always known. Dormant marketplaces (registered but
# with zero plugins installed from them -- e.g. superpowers-marketplace,
# claude-code-lsps, kong-se-skills) are intentionally absent: the superpowers
# and LSP plugins all ship from claude-plugins-official, and the project's own
# Nix LSP marketplace (nix-lsps) is generated in cfg/lsp-plugins.nix.
let
  # Active third-party marketplaces, pinned to commit SHAs. To update a
  # marketplace: bump its `sha` here (find the new HEAD with
  # `git -C ~/.claude/plugins/marketplaces/<name> rev-parse origin/main`).
  extraKnownMarketplaces = {
    kong-skills = {
      source = {
        source = "github";
        repo = "Kong/kong-skills";
        sha = "fe5c4d1b8f1fb3ee3b44e0124b6dd9cd54ebed22";
      };
    };
    impeccable = {
      source = {
        source = "github";
        repo = "pbakaus/impeccable";
        sha = "e3e22007a974fbb2023d36a3abf643f49dfd1fb3";
      };
    };
    hyperframes = {
      source = {
        source = "github";
        repo = "heygen-com/hyperframes";
        sha = "553688c996408cb33de27ce4573bef6c8cf27454";
      };
    };
  };

  # Complete desired enabled-plugin set. Keys are "<plugin>@<marketplace>".
  # Anything installed but absent here falls back to the plugin's own
  # defaultEnabled; listing every desired plugin makes enablement explicit and
  # reproducible (and is what drives auto-install from a clean state).
  enabledPlugins = {
    # --- claude-plugins-official (built-in marketplace) ---
    "frontend-design@claude-plugins-official" = true;
    "asana@claude-plugins-official" = true;
    "code-review@claude-plugins-official" = true;
    "context7@claude-plugins-official" = true;
    "github@claude-plugins-official" = true;
    "feature-dev@claude-plugins-official" = true;
    "commit-commands@claude-plugins-official" = true;
    "security-guidance@claude-plugins-official" = true;
    "pr-review-toolkit@claude-plugins-official" = true;
    "atlassian@claude-plugins-official" = true;
    "learning-output-style@claude-plugins-official" = true;
    "slack@claude-plugins-official" = true;
    "skill-creator@claude-plugins-official" = true;
    "ralph-loop@claude-plugins-official" = true;
    # LSP plugins (official marketplace, not the dormant claude-code-lsps)
    "gopls-lsp@claude-plugins-official" = true;
    "kotlin-lsp@claude-plugins-official" = true;
    "pyright-lsp@claude-plugins-official" = true;
    "rust-analyzer-lsp@claude-plugins-official" = true;
    # superpowers ships from the official marketplace, not superpowers-marketplace
    "superpowers@claude-plugins-official" = true;

    # --- kong-skills (Kong CS skills marketplace) ---
    "kong-skills@kong-skills" = true; # grand-meta: pulls the four below as deps
    "kong-skill@kong-skills" = true;
    "commit@kong-skills" = true;
    "feature-request@kong-skills" = true;
    "kong-doc-build@kong-skills" = true;

    # --- impeccable ---
    "impeccable@impeccable" = true;

    # --- hyperframes ---
    "hyperframes@hyperframes" = true;
  };

  settingsOverlay = pkgs.writeText "claude-plugin-overlay.json" (
    builtins.toJSON {
      inherit extraKnownMarketplaces enabledPlugins;
    }
  );
in
{
  # JSON file ({ extraKnownMarketplaces, enabledPlugins }) merged into the
  # deployed settings.json at activation.
  inherit settingsOverlay;
  # Plugin ids ("name@marketplace"), e.g. for the hyperframes runtime-dep gate.
  enabledPluginIds = builtins.attrNames enabledPlugins;
}
