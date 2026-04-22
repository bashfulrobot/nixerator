{
  lib,
  pkgs,
  config,
  globals,
  secrets,
  versions,
  ...
}:

let
  cfg = config.apps.cli.todoist-cli;
  todoistCli = pkgs.callPackage ./build { inherit versions; };
  hasToken = secrets ? todoist_token && secrets.todoist_token != "";
in
{
  options.apps.cli.todoist-cli.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the official Doist Todoist CLI (`td`). AI-friendly task creation, reading, and management.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ todoistCli ];

    # Seamless token injection: matches the GEMINI_API_KEY pattern in the
    # claude-code module. TODOIST_API_TOKEN always takes priority over
    # `td`'s stored keyring token (per the official CLI's docs), so there is
    # no `td auth login` step required; `td` just works everywhere.
    environment.variables = lib.optionalAttrs hasToken {
      TODOIST_API_TOKEN = secrets.todoist_token;
    };

    home-manager.users.${globals.user.name} = {
      home.sessionVariables = lib.optionalAttrs hasToken {
        TODOIST_API_TOKEN = secrets.todoist_token;
      };
    };
  };
}
