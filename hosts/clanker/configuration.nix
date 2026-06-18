{ hostname, globals, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./vm.nix
    ./modules.nix

    # Auto-import all modules
    ../../modules
  ];

  # Networking
  networking.hostName = hostname;

  # Localization (timezone via services.automatic-timezoned in the core suite)
  i18n.defaultLocale = globals.defaults.locale;

  # Boot straight into a logged-in TTY1 as the primary user. The core suite
  # sets this user's login shell to fish, whose login hook (see home.nix)
  # `exec sway`s on TTY1. No display manager, no greeter, no password.
  services.getty.autologinUser = globals.user.name;

  # Lean Claude host: full CLI/dev tooling, minimal headless desktop. Enable the
  # suites directly instead of the workstation archetype (which would pull
  # browsers, av, kong, k8s, etc.). The graphical layer is the minimal headless
  # Sway defined in home.nix, not hyprflake.
  suites = {
    core.enable = true; # ssh, tailscale, restic *tool* (no backup job), networking
    terminal.enable = true; # fish (login shell), starship, zellij, zoxide
    dev.enable = true; # claude-code, git (+ SSH commit signing), direnv, helix, go, python
  };

  # zellij + sshd + the `work` cross-host launcher. Makes clanker a peer in the
  # cross-device workflow (reachable from the phone via `work`).
  archetypes.claudeWorkHost.enable = true;
}
