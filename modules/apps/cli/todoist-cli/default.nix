{
  lib,
  pkgs,
  config,
  versions,
  ...
}:

let
  cfg = config.apps.cli.todoist-cli;
  todoistCli = pkgs.callPackage ./build { inherit versions; };
in
{
  options.apps.cli.todoist-cli.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the official Doist Todoist CLI (`td`). AI-friendly task creation, reading, and management.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ todoistCli ];

    # TODOIST_API_TOKEN is exported at shell runtime by the fish module, read
    # from the off-store secrets file (issue #265), so the token never enters
    # the Nix store. `td` prefers the env token over its keyring, so no
    # `td auth login` step is needed and `td` works everywhere the fish loader
    # has run.
  };
}
