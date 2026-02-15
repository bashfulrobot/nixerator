{
  lib,
  pkgs,
  config,
  versions,
  ...
}:

let
  cfg = config.apps.cli.happy;
  happyPackage = "happy-coder@${cfg.version}";
  happyCli = pkgs.writeShellScriptBin "happy" ''
    exec ${pkgs.nodejs_24}/bin/npm exec --yes --package "${happyPackage}" -- happy "$@"
  '';
  happyMcp = pkgs.writeShellScriptBin "happy-mcp" ''
    exec ${pkgs.nodejs_24}/bin/npm exec --yes --package "${happyPackage}" -- happy-mcp "$@"
  '';
in
{
  options = {
    apps.cli.happy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Happy CLI wrapper for Claude Code and Codex.";
      };

      version = lib.mkOption {
        type = lib.types.str;
        default = versions.cli.happy.version;
        description = "Pinned happy-coder npm version used by wrapper scripts.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      happyCli
      happyMcp
    ];
  };
}

