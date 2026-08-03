{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.gcmt;
  gcmt = pkgs.writeShellApplication {
    name = "gcmt";
    runtimeInputs = with pkgs; [
      git
      gum
      coreutils
    ];
    text = builtins.readFile ./scripts/gcmt.sh;
  };
in
{
  options.apps.cli.gcmt.enable = lib.mkEnableOption "gcmt — interactive conventional commit CLI tool";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ gcmt ];
  };
}
