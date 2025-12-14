{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.tailscale;
in
{
  options = {
    apps.cli.tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable tailscale mesh VPN.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable Tailscale
    services.tailscale.enable = true;

    environment.systemPackages = with pkgs; [
      tailscale # zero-config VPN
    ];

    # https://github.com/NixOS/nixpkgs/issues/180175#issuecomment-2372305193
    systemd.services.tailscaled.after = [
      "NetworkManager-wait-online.service"
    ];
  };
}
