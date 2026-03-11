{
  pkgs,
  config,
  lib,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.plannotator;
  plannotator = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.plannotator.enable = lib.mkEnableOption "plannotator interactive plan review for AI coding agents";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ plannotator ];

    home-manager.users.${globals.user.name} = {
      home.file = {
        ".claude/commands/plannotator-review.md".text = builtins.readFile ./commands/plannotator-review.md;
        ".claude/commands/plannotator-annotate.md".text =
          builtins.readFile ./commands/plannotator-annotate.md;
      };
    };
  };
}
