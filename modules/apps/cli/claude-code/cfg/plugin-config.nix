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
    # Kong's public AI marketplace (https://developer.konghq.com/skills/) --
    # ships the single `kong-konnect` plugin bundling the 20 Konnect product
    # skills (deck, kongctl, dev portal, terraform, gateway/observability
    # triage, ...). Distinct from kong-skills above, which is the internal CS
    # tooling marketplace.
    ai-marketplace.source = {
      source = "github";
      repo = "Kong/ai-marketplace";
      sha = "ef2dd6c9f0e770a694d91388dd7b02469cc43dca";
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
    # Fleet Deck: a localhost "mission control" board for Claude Code sessions
    # (https://github.com/lacion/fleet-deck). Ships one plugin, `fleetdeck`, from
    # a relative-path (`./`) source, so pinning the marketplace SHA pins the
    # plugin (same model as impeccable/hyperframes above). Runtime deps (Node,
    # tmux) are gated in default.nix on this id, not registered here.
    #
    # This is a young 0.x tool that hooks Claude Code's session lifecycle and
    # spawns tmux workers, so pin deliberately to a release tag you have run,
    # not to tracking HEAD. The SHA below is the v0.18.0 tag, whose manifest
    # tests against Claude Code 2.1.206 through 2.1.207. Re-check compatibility
    # (and skim the diff, since each bump re-grants a process-spawning surface)
    # when bumping the SHA or the pinned claude-code.
    #
    # Trust decision (accepted). Fleet Deck's board relays permission prompts
    # and offers an in-browser terminal across every local Claude Code session,
    # a larger grant than the render/capture plugins (impeccable, hyperframes).
    # Claude Code clones and runs the plugin at session start as the user (not at
    # activation, not as root; see cfg/activation.nix). That grant is acceptable
    # on the single-user, human-driven workstations this is enabled on, which is
    # why headless srv omits it (hosts/srv/modules.nix) and why each SHA bump is
    # a security review, not a routine bump. Do not enable it on any host that
    # runs Claude Code unattended, where no human is present to catch an
    # auto-approved prompt.
    #
    # The board binds loopback (127.0.0.1:4711). Port 4711 is never in any
    # host's allowedTCPPorts and the tailscale interface is not firewall-trusted,
    # so NixOS default-deny drops inbound to it even if a future version widened
    # the bind. The remaining question, whether a web page you merely visit could
    # reach the board, was verified against the pinned v0.18.0 source
    # (scripts/fleetd/http.mjs, tests/lan-auth.test.mjs):
    #   - Bind defaults to 127.0.0.1; LAN is an explicit opt-in (FLEETDECK_BIND).
    #   - A Host-header wall refuses any request whose Host re-resolves to the box
    #     (Host: evil.example gets 403), which is the DNS-rebinding defense.
    #   - A same-origin wall refuses every cross-origin state-changing POST, both
    #     WebSocket upgrades, and /api/spawn, so a visited page cannot drive the
    #     terminal or spawn agents.
    #   - The loopback token exemption only benefits local processes already
    #     running as the user; set FLEETDECK_REQUIRE_TOKEN=on to require the token
    #     even on loopback (for a shared machine, which these are not).
    # Re-verify these on each SHA bump; none of them is enforceable from Nix.
    fleetdeck.source = {
      source = "github";
      repo = "lacion/fleet-deck";
      sha = "5b91e17c602a7b7b25156617adc15d1278717883";
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
