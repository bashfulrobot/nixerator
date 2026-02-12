{ pkgs, lib, config, ... }:

let
  cfg = config.apps.cli.bluetooth-settings;

  bt-toggle = pkgs.writeShellScriptBin "bt-toggle" ''
    set -euo pipefail

    status=$(${lib.getExe' pkgs.util-linux "rfkill"} --noheadings --output SOFT --type bluetooth)

    if [ "$status" = "unblocked" ]; then
      rfkill block bluetooth
      echo "Bluetooth blocked"
    else
      rfkill unblock bluetooth
      echo "Bluetooth unblocked"
    fi
  '';
in
{
  options = {
    apps.cli.bluetooth-settings.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable bluetooth toggle script.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ bt-toggle ];
  };
}
