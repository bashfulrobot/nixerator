{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.nix-search-tv;
  username = globals.user.name;

  configFile = pkgs.writeText "nix-search-tv-config.json" (builtins.toJSON {
    indexes = [
      "nixpkgs"
      "home-manager"
      "nur"
      "nixos"
      "darwin"
    ];
    update_interval = "24h";
    enable_waiting_message = true;
  });
in
{
  options = {
    apps.cli.nix-search-tv.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable nix-search-tv fuzzy search for Nix packages.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Home Manager user configuration
    home-manager.users.${username} = {

      home.packages = with pkgs; [
        nix-search-tv
        fzf
      ];

      # Create config directory and file
      xdg.configFile."nix-search-tv/config.json".source = configFile;

      # Add fzf alias to fish shell
      programs.fish.shellAliases = lib.mkIf config.apps.cli.fish.enable {
        ns = "nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history";
      };

    };

  };
}
