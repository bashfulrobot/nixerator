{
  lib,
  pkgs,
  config,
  versions,
  secretsLib,
  ...
}:

let
  cfg = config.apps.cli.todoist-cli;
  # `td` reads TODOIST_API_TOKEN itself, so the wrapper loads it from the secauto
  # gopass store for each `td` process. No shell exports it.
  todoistCli = secretsLib.withGopassEnv {
    inherit pkgs;
    pkg = pkgs.callPackage ./build { inherit versions; };
    bin = "td";
    envVar = "TODOIST_API_TOKEN";
    entry = "todoist/credential";
  };
in
{
  options.apps.cli.todoist-cli.enable =
    lib.mkEnableOption "the official Doist Todoist CLI (`td`). AI-friendly task creation, reading, and management";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ todoistCli ];

    # TODOIST_API_TOKEN is read from the secauto gopass store by the wrapper above
    # at each `td` launch, so the token never enters the Nix store and no shell
    # exports it. `td` prefers the env token over its keyring, so no
    # `td auth login` step is needed.
  };
}
