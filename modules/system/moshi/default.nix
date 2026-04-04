{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.system.moshi;
in
{
  options = {
    system.moshi.enable = lib.mkEnableOption "Moshi - mosh server and tmux with sane defaults";
  };

  config = lib.mkIf cfg.enable {

    # Mosh: install package and open UDP ports
    environment.systemPackages = [ pkgs.mosh ];
    networking.firewall.allowedUDPPortRanges = [
      {
        from = 60000;
        to = 61000;
      }
    ];

    # Tmux: Home Manager programs.tmux with sane defaults
    home-manager.users.${globals.user.name} = {
      programs.tmux = {
        enable = true;
        mouse = true;
        historyLimit = 50000;
        baseIndex = 1;
        terminal = "tmux-256color";
        escapeTime = 0;
        aggressiveResize = true;
        prefix = "C-a";
        keyMode = "vi";
      };
    };
  };
}
