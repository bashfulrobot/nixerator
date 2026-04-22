{
  globals,
  inputs,
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
      util-linux # setsid
    ];
    text = builtins.readFile ./scripts/claude-remote.sh;
  };

  towerGuard = pkgs.writeShellApplication {
    name = "claude-control-tower-guard";
    runtimeInputs = with pkgs; [
      coreutils
      jq
    ];
    text = builtins.readFile ./scripts/control-tower-guard.sh;
  };

  towerDir = "${globals.user.homeDirectory}/.local/share/claude-control-tower";

  towerSettings = pkgs.writeText "claude-control-tower-settings.json" (
    builtins.toJSON {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
      permissions = {
        allow = [
          "Bash(claude-remote)"
          "Bash(claude-remote *)"
        ];
        deny = [ ];
      };
      hooks = {
        PreToolUse = [
          {
            hooks = [
              {
                type = "command";
                command = "${towerGuard}/bin/claude-control-tower-guard";
              }
            ];
          }
        ];
      };
      remoteControlEnabled = true;
      cleanupPeriodDays = 15;
    }
  );
in
{
  options.apps.cli.claude-remote = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the `claude-remote` CLI. Spawns detached
        `claude remote-control` servers in repos under $HOME/git/.
        Intended to be invoked from inside the always-on control-tower
        session (see `controlTower.enable`) so that new sessions can
        be created from your phone via claude.ai/code.
      '';
    };
    controlTower.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run a permanent `claude remote-control` server as a
        `systemd --user` service, locked (via PreToolUse hook) to only
        invoking the `claude-remote` CLI. This is the "tower" you
        attach to from your phone to spawn new sessions on demand.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [ claude-remote ];
    })

    (lib.mkIf cfg.controlTower.enable {
      assertions = [
        {
          assertion = cfg.enable;
          message = "apps.cli.claude-remote.controlTower.enable requires apps.cli.claude-remote.enable = true.";
        }
      ];

      home-manager.users.${globals.user.name} = {
        xdg.dataFile = {
          "claude-control-tower/CLAUDE.md".source = ./cfg/control-tower-CLAUDE.md;
          "claude-control-tower/.claude/settings.json".source = towerSettings;
        };

        # claude refuses to start in an untrusted workspace. The dialog is
        # interactive, so pre-accept it for the tower dir by patching
        # ~/.claude.json in place. Idempotent — safe to re-run.
        home.activation.claudeControlTowerTrust =
          inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ]
            ''
              claude_json="${globals.user.homeDirectory}/.claude.json"
              if [ -f "$claude_json" ]; then
                tmp="$(${pkgs.coreutils}/bin/mktemp)"
                ${pkgs.jq}/bin/jq --arg d "${towerDir}" '
                  .projects = (.projects // {})
                  | .projects[$d] = (.projects[$d] // {})
                  | .projects[$d].hasTrustDialogAccepted = true
                ' "$claude_json" > "$tmp" \
                  && $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv "$tmp" "$claude_json"
              fi
            '';

        systemd.user.services.claude-control-tower = {
          Unit = {
            Description = "Claude Code control tower (always-on remote-control server)";
            After = [ "graphical-session.target" ];
          };
          Service = {
            Type = "simple";
            WorkingDirectory = towerDir;
            # `claude remote-control` is a proper daemon -- no PTY required,
            # accepts a closed stdin, and stays running until killed.
            ExecStart = "${pkgs.llm-agents.claude-code}/bin/claude remote-control --name claude-control-tower --permission-mode bypassPermissions";
            UnsetEnvironment = "CLAUDE_CODE_REMOTE CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_CONTAINER_ID CLAUDECODE";
            Restart = "always";
            RestartSec = 5;
            StandardInput = "null";
            StandardOutput = "journal";
            StandardError = "journal";
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      };
    })
  ];
}
