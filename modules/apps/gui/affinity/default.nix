{ globals, lib, config, inputs, ... }:

let
  cfg = config.apps.gui.affinity;
  username = globals.user.name;
in
{
  options = {
    apps.gui.affinity.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Affinity creative suite (Photo, Designer, Publisher).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.affinity-nix.packages.x86_64-linux.v3
    ];

    home-manager.users.${username} = {
      programs.fish.shellAliases = lib.mkIf config.apps.cli.fish.enable {
        affinity-update = "nix run github:mrshmllow/affinity-nix#{v3,photo,designer,publisher} -- update";
      };
    };
  };
}
