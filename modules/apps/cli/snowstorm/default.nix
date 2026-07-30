{
  pkgs,
  lib,
  config,
  inputs,
  globals,
  ...
}:

let
  cfg = config.apps.cli.snowstorm;
  snowstorm = inputs.snowstorm.packages.${pkgs.stdenv.hostPlatform.system}.default;
  homeDir = globals.user.homeDirectory;

  # Tool-wide defaults, NOT the Snowflake connection profile (see below).
  # No account-identifying or secret fields here -- just this user's stated
  # day-to-day preference for a scannable table over raw JSON, and where
  # saved queries live on this workstation. `connection` is deliberately
  # left unset: it comes from connections.toml's own default-connection
  # marker instead, so it stays resolved at the flag/env layer.
  snowstormConfigToml = pkgs.writeText "snowstorm-config.toml" ''
    format    = "table"
    human     = true
    query_dir = "${homeDir}/dev/kong/snowstorm/queries/"
  '';
in
{
  options = {
    apps.cli.snowstorm.enable = lib.mkEnableOption "snowstorm - Snowflake data-access CLI (github.com/bashfulrobot/snowstorm)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ snowstorm ];

    # ~/.snowflake/connections.toml is NOT written here. Auth is
    # externalbrowser (interactive SSO, no password/token), but the file
    # still names the internal account locator/role/warehouse/database/
    # schema, which we keep out of this repo the same way SSH keys are: a
    # 1Password Document ("snowflake-connections-toml") materialized by
    # `render-secrets` (modules/apps/cli/render-secrets), workstations only.
    # Run `just render-secrets` after enabling this on a new host.

    home-manager.users.${globals.user.name} = {
      home.file.".snowstorm/config.toml".source = snowstormConfigToml;
    };
  };
}
