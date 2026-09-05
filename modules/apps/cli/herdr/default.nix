{
  globals,
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.herdr;

  # From the llm-agents input (numtide/llm-agents.nix), the same source
  # claude-code and opencode already come from -- so `just qu` moves herdr with
  # everything else and no separate flake input or version pin is needed.
  # Upstream ships its own flake (github:herdrdev/herdr), but pulling that in
  # would add a second nixpkgs to follow for a package this one already builds.
  herdr = pkgs.llm-agents.herdr;

  # Only settings that DEPART from a herdr default live here, each with the
  # reason inline. `herdr --default-config` prints the full default set and
  # https://herdr.dev/docs/config-reference/ documents every key -- copying
  # either one in wholesale would turn every future upstream default change
  # into a value this repo silently pins.
  #
  # The same four settings the donkeykong repo deploys with chezmoi
  # (home/dot_config/herdr/config.toml). herdr reads ~/.config/herdr/config.toml
  # on Linux and macOS alike, so both machines run the same values -- only the
  # comments differ, because the deployment mechanism does. Change one setting
  # and change the other.
  configToml = ''
    # herdr config. Managed by Nix -- edit
    # modules/apps/cli/herdr/default.nix, then `just qr` and
    # `herdr server reload-config` (or `reload config` from the global menu) to
    # pick it up without restarting panes.
    #
    # herdr runs coding-agent sessions under a background server so a closed
    # terminal, a dropped SSH connection or a reboot does not end them. It works
    # with no config file at all; everything below is a deliberate departure
    # from a default.

    # Skip first-run onboarding. Without it herdr shows the onboarding flow and
    # writes `onboarding = false` back into this file when you finish it. That
    # write fails here -- xdg.configFile deploys a read-only symlink into the
    # Nix store -- so setting it means herdr never has cause to try.
    onboarding = false

    [theme]
    # Follow the terminal's own ANSI palette instead of herdr's bundled
    # "catppuccin". stylix already themes kitty (globals.preferences.terminal),
    # so this buys one source of truth rather than a second copy that can drift:
    # restyle the system and herdr follows. Set "catppuccin" if herdr's own
    # chrome reads better.
    name = "terminal"

    [ui.toast]
    # Default is "herdr", an in-app toast -- useless when the reason to run
    # agents under herdr is *not* watching them, so it has to be able to
    # interrupt. "terminal" hands the notification to the outer terminal
    # (OSC 99) and, unlike "system", works over SSH, so an agent left running on
    # srv can still reach whoever is attached from elsewhere.
    delivery = "terminal"

    [update]
    # Nix owns this install, so `just qu` upgrades herdr with everything else.
    # Left on, the background check notifies in-app and points at `herdr
    # update` -- which herdr's own docs say not to run on a package-manager
    # install, because it replaces the managed binary behind its back.
    #
    # update.manifest_check is deliberately left alone: it refreshes
    # agent-detection manifests, not the binary, and has nothing to do with how
    # herdr was installed.
    version_check = false
  '';

  # `herdr integration install claude` writes ~/.claude/hooks/herdr-agent-state.sh
  # and adds hook entries to ~/.claude/settings.json. Without it herdr still
  # runs Claude Code, but it infers each agent's state by reading the screen
  # instead of being told, and cannot restore a pane into its native
  # conversation session.
  #
  # On macOS (the donkeykong repo) this is a per-machine step run by hand,
  # because ~/.claude/settings.json is deliberately unmanaged there. Here it
  # cannot be: cfg/activation.nix rewrites settings.json from the repo copy on
  # every rebuild, so a hand-run install would be silently reverted by the next
  # `just qr`. Re-running the installer at activation -- after that rewrite --
  # is the only shape that survives. The command is idempotent.
  #
  # The hook entries it adds are stripped back out on capture (cfg/fish.nix),
  # so the repo's settings.json never gains a home-only path the other hosts
  # cannot resolve.
  claudeIntegrationActivation = ''
    claude_home="${globals.user.homeDirectory}/.claude"
    if [ -z "$DRY_RUN_CMD" ]; then
      # claude-code's own activation creates this directory. Skip rather than
      # create it, so herdr is never the reason a stray ~/.claude exists.
      if [ -d "$claude_home" ]; then
        ${herdr}/bin/herdr integration install claude >/dev/null 2>&1 ||
          echo "herdr: 'herdr integration install claude' failed -- run it by hand, then 'herdr integration status'" >&2
      fi
    else
      $DRY_RUN_CMD "would run herdr integration install claude"
    fi
  '';

  # Must run AFTER claude-code rebuilds settings.json from the repo copy, or the
  # hook entries are written and then thrown away in the same activation. Only
  # name that entry when it exists -- home-manager's DAG errors on a dangling
  # dependency, and a host can enable herdr without claude-code.
  claudeIntegrationAfter = [
    "writeBoundary"
  ]
  ++ lib.optional config.apps.cli.claude-code.enable "claudeCodeConfig";
in
{
  options.apps.cli.herdr = {
    enable = lib.mkEnableOption "herdr, a multiplexer for coding-agent sessions";

    claudeIntegration.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.apps.cli.claude-code.enable;
      defaultText = lib.literalExpression "config.apps.cli.claude-code.enable";
      description = ''
        Install herdr's Claude Code hook at activation
        (`herdr integration install claude`), so herdr is told each agent's
        state rather than inferring it from the screen, and can restore a pane
        into its native conversation session.

        Defaults to whether Claude Code itself is enabled. Set it false to leave
        `~/.claude` untouched by this module.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ herdr ];

    home-manager.users.${globals.user.name} = {
      # No programs.herdr / services.herdr module exists upstream or in
      # home-manager, so xdg.configFile is the fallback (modules/CLAUDE.md).
      # The read-only store symlink is the trade: herdr only reads this file at
      # startup and on `herdr server reload-config`, but its in-app settings
      # panel and `herdr config reset-keys` write to it and will fail. Change
      # settings here, not in the panel.
      xdg.configFile."herdr/config.toml".text = configToml;

      home.activation = lib.optionalAttrs cfg.claudeIntegration.enable {
        herdrClaudeIntegration =
          inputs.home-manager.lib.hm.dag.entryAfter claudeIntegrationAfter
            claudeIntegrationActivation;
      };
    };
  };
}
