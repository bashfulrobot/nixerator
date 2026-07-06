{ globals, lib, ... }:

{
  # Home Manager configuration for srv host
  home = {
    username = globals.user.name;
    homeDirectory = lib.mkForce globals.user.homeDirectory;
    # Home Manager state version
    inherit (globals.defaults) stateVersion;
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Persistent ssh-agent for this headless remote-dev host. `keychain`
  # starts (or re-attaches to) a single ssh-agent and writes its env
  # to ~/.keychain/<host>-fish; sourcing that file exports
  # SSH_AUTH_SOCK/SSH_AGENT_PID so every interactive shell shares
  # one agent, and `ssh-add -l` / passphrase unlocks survive logouts
  # until the next reboot. Scoped to srv only — workstations have
  # their own agents (1Password / gnome-keyring) and must not run this.
  programs.fish.interactiveShellInit = ''
    if command -q keychain
      keychain --quiet --agents ssh ~/.ssh/id_ed25519
      set -l _kc_env ~/.keychain/(hostname)-fish
      if test -f $_kc_env
        source $_kc_env
      end
    end

  '';
}
