{ username, globals, lib, ... }:

{
  # Home Manager configuration for srv host
  home = {
    inherit username;
    homeDirectory = lib.mkForce globals.user.homeDirectory;
    # Home Manager state version
    inherit (globals.defaults) stateVersion;
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Server-specific home manager configuration
  # (minimal for server, most config happens at system level)
}
