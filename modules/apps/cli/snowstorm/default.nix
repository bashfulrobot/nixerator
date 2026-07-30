{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  cfg = config.apps.cli.snowstorm;
  snowstorm = inputs.snowstorm.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
  };
}
