{ ... }:

{
  # Manually import ONLY the modules clanker needs (srv pattern). NO
  # `../../modules` auto-import, NO suites, NO hyprflake/stylix/desktop.
  # Adding a module here requires both the import path AND the enable below.
  imports = [
    # CLI / claude stack
    ../../modules/apps/cli/agent-scan
    ../../modules/apps/cli/agentos
    ../../modules/apps/cli/claude-code
    ../../modules/apps/cli/gcmt
    ../../modules/apps/cli/gemini-cli
    ../../modules/apps/cli/graymatter
    ../../modules/apps/cli/skillfish
    ../../modules/apps/cli/superpowers

    # Shell / terminal
    ../../modules/apps/cli/fish
    ../../modules/apps/cli/starship
    ../../modules/apps/cli/work-launcher
    ../../modules/apps/cli/zellij
    ../../modules/apps/cli/zoxide

    # Dev tooling
    ../../modules/apps/cli/direnv
    ../../modules/apps/cli/git
    ../../modules/apps/cli/helix
    ../../modules/apps/cli/nix

    # Secrets / networking / system
    ../../modules/apps/cli/render-secrets
    ../../modules/apps/cli/tailscale
    ../../modules/dev/go
    ../../modules/dev/python
    ../../modules/system/ssh

    # Required only to DECLARE the `system.caddy` option namespace. The zellij
    # module has a `lib.mkIf cfg.service.enable { system.caddy = ...; }` branch;
    # even with service.enable false (the default here), the module system must
    # type-check that `system.caddy` definition, which needs the option declared.
    # caddy itself stays disabled (system.caddy.enable defaults false, not set).
    ../../modules/system/caddy

    # Archetype: zellij + work-launcher + system.ssh
    ../../modules/archetypes/claudeWorkHost
  ];

  # Adopts the Claude work-host archetype: zellij (no web, no mosh), sshd,
  # work-launcher. This already enables zellij + work-launcher + system.ssh,
  # so those three are NOT enabled separately below (the module dirs are still
  # imported above, exactly as srv does).
  archetypes.claudeWorkHost.enable = true;

  # CLI applications
  apps.cli = {
    # Shell / terminal
    fish.enable = true;
    starship.enable = true;
    zoxide.enable = true;

    # Dev tooling
    direnv.enable = true;
    git.enable = true;
    helix.enable = true;
    nix.enable = true;

    # Secrets / networking
    render-secrets.enable = true;
    tailscale.enable = true;

    # Claude Code stack
    agent-scan.enable = true;
    agentos.enable = true;
    claude-code = {
      enable = true;
      serverProfile = "minimal";
    };
    gcmt.enable = true;
    gemini-cli.enable = true;
    graymatter.enable = true;
    skillfish.enable = true;
    superpowers.enable = true;
  };

  # Dev languages
  dev = {
    go.enable = true;
    python.enable = true;
  };
}
