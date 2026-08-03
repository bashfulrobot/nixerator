{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.skill-cache;
  skill-cache = pkgs.writeShellApplication {
    name = "skill-cache";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    text = builtins.readFile ./scripts/skill-cache.sh;
  };
in
{
  options.apps.cli.skill-cache.enable =
    lib.mkEnableOption "skill-cache — warm cache CLI for query skills";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ skill-cache ];
  };
}
