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

  # Tool-wide defaults, NOT the Snowflake connection profile (see below).
  # No account-identifying or secret fields here -- just this user's stated
  # day-to-day preference for a scannable table over raw JSON. `connection`
  # and `query_dir` are deliberately left unset: they either come from
  # connections.toml's own default-connection marker, or vary per host/task,
  # so they stay resolved at the flag/env layer instead of being pinned here.
  snowstormConfigToml = pkgs.writeText "snowstorm-config.toml" ''
    format = "table"
    human  = true
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
