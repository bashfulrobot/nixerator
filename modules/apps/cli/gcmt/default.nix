{ lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.gcmt;
  gcmt = pkgs.writeShellApplication {
    name = "gcmt";
    runtimeInputs = with pkgs; [ git gum coreutils ];
    text = builtins.readFile ./scripts/gcmt.sh;
  };
in
{
  options.apps.cli.gcmt.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable gcmt — interactive conventional commit CLI tool.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ gcmt ];
  };
}
