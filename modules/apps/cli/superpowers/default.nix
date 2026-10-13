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

  # The superpowers plugin itself (superpowers@claude-plugins-official) is
  # enabled by the claude-stack manifest snapshot (cfg/plugin-config.nix), not
  # here. This module is kept as the enable switch other modules/hosts already
  # reference; it adds no config of its own.
  config = lib.mkIf cfg.enable { };
}
