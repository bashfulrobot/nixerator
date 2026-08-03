{
  lib,
  config,
  ...
}:
let
  cfg = config.apps.cli.superpowers;
in
{
  options = {
    apps.cli.superpowers.enable = lib.mkEnableOption "superpowers agentic skills framework for Claude Code";
  };

  config = lib.mkIf cfg.enable {
    apps.cli.claude-code.plugins = [
      "superpowers@claude-plugins-official"
    ];
  };
}
