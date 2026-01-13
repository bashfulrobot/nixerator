{ username, globals, lib, ... }:

{
  # Home Manager configuration for srv host
  home.username = username;
  home.homeDirectory = lib.mkForce globals.user.homeDirectory;

  # Home Manager state version
  home.stateVersion = globals.defaults.stateVersion;

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Server-specific home manager configuration
  # (minimal for server, most config happens at system level)
}
