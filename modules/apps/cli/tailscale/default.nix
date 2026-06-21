{
  lib,
  pkgs,
  config,
  ...
}:

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
    services.tailscale = {
      enable = true;

      # Use the regular OpenSSH daemon (system.ssh) for SSH access, NOT the
      # Tailscale SSH server (issue #107). `tailscale set --ssh=false` runs on
      # every activation via the module's tailscaled-set service, so any node
      # that previously had Tailscale SSH enabled gets it switched off, and we
      # never pass `--ssh` to `tailscale up`. Nodes are brought onto the tailnet
      # manually (OAuth / terminal login), so no auth-key auto-join is wired
      # here -- this avoids the 90-day auth-key expiry treadmill.
      extraSetFlags = [ "--ssh=false" ];
    };

    environment.systemPackages = with pkgs; [
      tailscale # zero-config VPN
    ];

    # https://github.com/NixOS/nixpkgs/issues/180175#issuecomment-2372305193
    systemd.services.tailscaled.after = [
      "NetworkManager-wait-online.service"
    ];
  };
}
