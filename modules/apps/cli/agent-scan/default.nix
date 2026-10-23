{
  lib,
  pkgs,
  config,
  globals,
  versions,
  secretsLib,
  ...
}:

let
  cfg = config.apps.cli.agent-scan;
  # snyk-agent-scan reads SNYK_TOKEN itself, so the wrapper loads it from the
  # secauto gopass store for each run. No shell exports it.
  agent-scan = secretsLib.withGopassEnv {
    inherit pkgs;
    pkg = pkgs.callPackage ./build { inherit versions; };
    bin = "snyk-agent-scan";
    envVar = "SNYK_TOKEN";
    entry = "snyk/credential";
  };
in
{
  options.apps.cli.agent-scan = {
    enable = lib.mkEnableOption "Snyk agent-scan -- security scanner that discovers and audits AI agent components (MCP servers, skills, tools) for prompt injection, tool poisoning, and credential risks";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [ agent-scan ];

      # SNYK_TOKEN comes from the secauto gopass store via the wrapper above, so it
      # never enters the Nix store and is not exported by any shell.
    };
  };
}
