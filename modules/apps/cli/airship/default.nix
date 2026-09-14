{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.airship;

  # Wraps `npx` rather than pinning a nixpkgs-built derivation (the
  # todoist-cli/skillfish pattern): Airship is an early-stage, fast-moving
  # visual-dev tool whose own docs recommend `npx @airshiplabs/cli`, and it
  # has no vendorable package-lock in its published tarball. A pinned build
  # would mean re-vendoring the lock and recomputing npmDepsHash on every
  # release for no real benefit here -- always-latest is what's wanted.
  airship = pkgs.writeShellApplication {
    name = "airship";
    runtimeInputs = with pkgs; [ nodejs ];
    text = ''
      exec npx --yes @airshiplabs/cli@latest "$@"
    '';
  };
in
{
  options.apps.cli.airship.enable =
    lib.mkEnableOption "Airship -- visual editor that puts a Figma-like canvas in front of a running dev server and hands selected-element edits to a coding agent (Claude Code, Codex, OpenCode). https://www.airship.design";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ airship ];
  };
}
