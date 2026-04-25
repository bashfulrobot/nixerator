{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.agent-scan;
  agent-scan = pkgs.callPackage ./build { inherit versions; };
in
{
  options.apps.cli.agent-scan = {
    enable = lib.mkEnableOption "Snyk agent-scan -- security scanner that discovers and audits AI agent components (MCP servers, skills, tools) for prompt injection, tool poisoning, and credential risks";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [ agent-scan ];
    };
  };
}
