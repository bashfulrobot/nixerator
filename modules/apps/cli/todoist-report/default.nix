{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.todoist-report;
  todoistReport = pkgs.writeShellApplication {
    name = "todoist-report";
    runtimeInputs = with pkgs; [
      curl
      gum
      jq
    ];
    text = builtins.readFile ./scripts/todoist-report.sh;
  };
in
{
  options.apps.cli.todoist-report.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable todoist-report CLI tool.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ todoistReport ];
  };
}
