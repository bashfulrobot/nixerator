{ lib, config, ... }:

let
  cfg = config.archetypes.claudeWorkHost;
in
{
  options.archetypes.claudeWorkHost.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable the Claude work-host archetype: zellij + mosh via system.ssh,
      sshd, and the work launcher. Sessions started on this host stay on
      this host and are attachable from any peer via the `work` fish
      function or directly via SSH + `zellij attach`.
    '';
  };

  config = lib.mkIf cfg.enable {
    apps = {
      cli = {
        zellij = {
          enable = true;
          hideStatusBar = true;
          cheatsheet.enable = true;
        };
        work-launcher.enable = true;
      };
    };
    system.ssh.enable = true;
  };
}
