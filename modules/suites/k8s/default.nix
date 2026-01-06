{ lib, pkgs, config, ... }:

let
  cfg = config.suites.k8s;
in
{
  options = {
    suites.k8s.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Kubernetes tooling suite.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Kubernetes tools
    environment.systemPackages = with pkgs; [
      kubectl              # Kubernetes command-line tool
      talosctl             # Talos OS management tool
      omnictl              # Omni CLI
    ];
  };
}
