{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.happy;
  happy = pkgs.callPackage ./build { inherit versions; };
  claude-code = pkgs.llm-agents.claude-code;
in
{
  options.apps.cli.happy = {
    enable = lib.mkEnableOption "Happy Coder - Claude Code mobile companion";

    daemon.enable = lib.mkEnableOption "Happy Coder daemon (systemd user service)";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home-manager.users.${globals.user.name} = {
          home.packages = [ happy ];

          # Happy Coder looks for claude in ~/.local/bin/claude (native installer path).
          # NixOS installs claude-code via nix profile, so we symlink it.
          home.file.".local/bin/claude".source = "${claude-code}/bin/claude";
        };
      }

      (lib.mkIf cfg.daemon.enable {
        home-manager.users.${globals.user.name} = {
          systemd.user.services.happy-daemon = {
            Unit = {
              Description = "Happy Coder daemon for remote Claude Code sessions";
              After = [ "network.target" ];
            };
            Service = {
              ExecStart = "${happy}/bin/happy daemon start";
              ExecStop = "${happy}/bin/happy daemon stop";
              RemainAfterExit = true;
              Restart = "on-failure";
              RestartSec = 5;
            };
            Install = {
              WantedBy = [ "default.target" ];
            };
          };
        };
      })
    ]
  );
}
