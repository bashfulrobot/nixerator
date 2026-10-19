{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.sandcastle;

  # Wraps `npx` rather than pinning a nixpkgs-built derivation (the
  # airship/todoist-cli pattern): Sandcastle is a fast-moving npm package
  # (@ai-hero/sandcastle) whose `init` scaffolds a per-repo `.sandcastle/`
  # that imports the library from the repo's own node_modules. The global
  # command only needs to run `init` and the image-build subcommands, so
  # always-latest beats re-vendoring an npm lock on every release.
  sandcastle = pkgs.writeShellApplication {
    name = "sandcastle";
    runtimeInputs = with pkgs; [ nodejs ];
    text = ''
      exec npx --yes @ai-hero/sandcastle@latest "$@"
    '';
  };
in
{
  options.apps.cli.sandcastle.enable =
    lib.mkEnableOption "Sandcastle -- TypeScript orchestrator that runs coding agents (Claude Code and others) in Docker/Podman sandboxes on throwaway git branches and merges the commits back. Needs apps.cli.docker. https://github.com/mattpocock/sandcastle";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ sandcastle ];

    # Sandcastle's default provider is Docker; fail the build instead of
    # shipping a command whose first `run()` dies on a missing daemon.
    assertions = [
      {
        assertion = config.apps.cli.docker.enable;
        message = "apps.cli.sandcastle needs apps.cli.docker.enable = true (suites.infrastructure turns it on).";
      }
    ];
  };
}
