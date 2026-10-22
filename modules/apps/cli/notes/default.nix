{
  config,
  globals,
  inputs,
  lib,
  pkgs,
  versions,
  ...
}:

let
  cfg = config.apps.cli.notes;

  markless = pkgs.callPackage ./build/markless.nix { inherit versions; };
  weave = pkgs.callPackage ./build/weave.nix { inherit versions; };

  # The scripts are plain portable bash so the macOS port can copy cfg/ as is.
  # writeShellApplication adds the NixOS-side PATH and runs shellcheck at
  # build time.
  script =
    name: runtimeInputs:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      runtimeEnv = {
        NOTES_DIR = cfg.root;
        NOTES_SHARE = "${./cfg}";
      };
      text = builtins.readFile (./cfg + "/${name}.bash");
    };

  notesOpen = script "notes-open" [ markless ];
  notes = script "notes" [
    pkgs.zk
    pkgs.fzf
    pkgs.bat
    pkgs.fuzzel
    notesOpen
  ];
  notesNew = script "notes-new" [
    pkgs.zk
    pkgs.fzf
    notesOpen
  ];
  notesInit = script "notes-init" [ pkgs.coreutils ];
  notesMedia = script "notes-media" [
    pkgs.coreutils
    pkgs.wl-clipboard
  ];
  notesWeaveMedia = script "notes-weave-media" [
    pkgs.coreutils
    pkgs.findutils
  ];
in
{
  options.apps.cli.notes = {
    enable = lib.mkEnableOption "plain-markdown notes system (zk, markless, fzf picker, Weave)";

    root = lib.mkOption {
      type = lib.types.str;
      default = globals.paths.notes;
      description = "Notes root. Plain folders of markdown, each with its own media/ folder.";
    };

    weave = {
      enable = lib.mkEnableOption "Weave, the zk web frontend, for reading notes from a phone or tablet";

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        example = "100.74.137.95";
        description = ''
          Address Weave binds to. Set it to this host's Tailscale IP so only the
          tailnet can reach it. Weave has no TLS: use `tailscale serve` for HTTPS.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8000;
        description = "Weave listen port. Opened on tailscale0 only.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/home/dustin/.config/weave/env";
        description = ''
          Path to an env file containing `WEAVE_PASSWORD=...`, read by systemd.
          Without it Weave disables login and anyone who can reach the port can
          read and edit every note. The file lives outside the Nix store.
        '';
      };
    };

    keybind = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Bind SUPER+CTRL+N to the fuzzel note launcher in Hyprland. Needs the
        hyprflake module, so it is off by default. (SUPER+N and SUPER+SHIFT+N
        are taken by hyprflake for notifications and the DMS notepad.)
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        markless
        notes
        notesInit
        notesMedia
        notesNew
        notesOpen
        notesWeaveMedia
        pkgs.bat
        pkgs.fuzzel
        pkgs.fzf
        pkgs.ripgrep
        pkgs.zk
      ]
      ++ lib.optional cfg.weave.enable weave;

      home-manager.users.${globals.user.name} = {
        home.sessionVariables = {
          NOTES_DIR = cfg.root;
          ZK_NOTEBOOK_DIR = cfg.root;
        };

        # Create the hierarchy on every activation. notes-init never overwrites.
        home.activation.notesInit = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${notesInit}/bin/notes-init >/dev/null
        '';

        hyprflake.hyprland.extraLua = lib.mkIf cfg.keybind {
          "notes" = ''
            hl.bind("SUPER + CTRL + N",
              hl.dsp.exec_cmd("${notes}/bin/notes -l"))
          '';
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.weave.enable) {
      warnings =
        lib.optional (cfg.weave.passwordFile == null && cfg.weave.listenAddress != "127.0.0.1")
          ''
            apps.cli.notes.weave has no passwordFile and listens on ${cfg.weave.listenAddress}:
            every device that can reach that address can read and edit all notes.
          '';

      # Weave serves <root> as a zk notebook. Its images are flattened into
      # <root>/media by notes-weave-media (before each start and every 2 minutes).
      systemd = {
        services = {
          notes-weave-media = {
            description = "Flatten per-folder media into the Weave attachment directory";
            serviceConfig = {
              Type = "oneshot";
              User = globals.user.name;
              ExecStart = "${notesWeaveMedia}/bin/notes-weave-media";
            };
          };

          weave = {
            description = "Weave notes web frontend";
            wantedBy = [ "multi-user.target" ];
            after = [
              "network-online.target"
              "tailscaled.service"
            ];
            wants = [ "network-online.target" ];
            environment = {
              ZK_NOTEBOOK_DIR = cfg.root;
              WEAVE_ATTACHMENTS = "media";
              WEAVE_HOST = cfg.weave.listenAddress;
              WEAVE_PORT = toString cfg.weave.port;
            };
            serviceConfig = {
              User = globals.user.name;
              Group = "users";
              ExecStartPre = "${notesWeaveMedia}/bin/notes-weave-media";
              ExecStart = "${weave}/bin/weave";
              # The Tailscale address does not exist until tailscaled is up.
              Restart = "on-failure";
              RestartSec = 10;
              # Weave is a network-facing web app that runs as the login user.
              # Confine it to the notebook: the rest of $HOME (~/.ssh, the
              # rendered secrets file) is hidden behind an empty tmpfs.
              ProtectHome = "tmpfs";
              BindPaths = [ cfg.root ];
              ProtectSystem = "strict";
              PrivateTmp = true;
              PrivateDevices = true;
              NoNewPrivileges = true;
              ProtectKernelTunables = true;
              ProtectKernelModules = true;
              ProtectControlGroups = true;
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_INET6"
                "AF_UNIX"
              ];
              RestrictNamespaces = true;
              LockPersonality = true;
              SystemCallFilter = [ "@system-service" ];
              CapabilityBoundingSet = "";
            }
            // lib.optionalAttrs (cfg.weave.passwordFile != null) {
              EnvironmentFile = cfg.weave.passwordFile;
            };
          };
        };

        timers.notes-weave-media = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1min";
            OnUnitActiveSec = "2min";
          };
        };
      };

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.weave.port ];
    })
  ];
}
