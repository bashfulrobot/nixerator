{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.claude-remote;
  claude-remote = pkgs.writeShellApplication {
    name = "claude-remote";
    runtimeInputs = with pkgs; [
      coreutils
      git
      systemd
    ];
    text = builtins.readFile ./scripts/claude-remote.sh;
  };
in
{
  options.apps.cli.claude-remote.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable claude-remote — manage Claude Code remote-control sessions
      as transient systemd --user services. Lets you spawn ad-hoc
      remote-controllable sessions in any repo under $HOME/git/ from
      another Claude Code session or local shell.
    '';
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ claude-remote ];
  };
}
