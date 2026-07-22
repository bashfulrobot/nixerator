{
  globals,
  lib,
  config,
  ...
}:

let
  cfg = config.apps.cli.ballpoint;
in
{
  options = {
    apps.cli.ballpoint.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable ballpoint, the local Todoist triage tool (walk / probe / dispatch), with the scheduled freshness prewarm probe.";
    };
  };

  config = lib.mkIf cfg.enable {
    # programs.ballpoint comes from inputs.ballpoint.homeManagerModules.default,
    # imported in flake.nix for the workstation hosts. secretsPath is left at its
    # default (null), so ballpoint reads ~/.config/nixos-secrets/secrets.json,
    # which is where `just render-secrets` already writes todoist_token. No
    # secret value enters the store; only the runtime path is used.
    home-manager.users.${globals.user.name} = {
      programs.ballpoint = {
        enable = true;
        prewarm.enable = true;
      };
    };
  };
}
