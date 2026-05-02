{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.cli.zellij;
  caddyCfg = config.system.caddy;

  # Path to the rendered cheat sheet on the system. Kept on /etc so the
  # zellij keybind can reference it from any user, and so the file is
  # immutable / managed by the nix store.
  cheatsheetPath = "/etc/zellij/cheatsheet.md";

  # `bat` invocation used by the floating-pane keybind. Pinned to the
  # store path so it always resolves regardless of the inner pane's
  # PATH (which inherits from cfg.defaultShell).
  cheatsheetCmd = "${pkgs.bat}/bin/bat";

  # Custom layout that omits zellij's tab-bar AND status-bar plugins,
  # giving the full terminal to the active pane. Combined with the
  # cheat sheet keybind, the user trades the always-on shortcut strip
  # for an on-demand reference.
  noBarLayoutKdl = ''
    layout {
        pane
    }
  '';

  configKdl = ''
    default_shell "${cfg.defaultShell}"
    ${lib.optionalString cfg.hideStatusBar ''default_layout "no-bar"''}
    ${lib.optionalString cfg.cheatsheet.enable ''
      keybinds {
          shared {
              bind "${cfg.cheatsheet.keybind}" {
                  Run "${cheatsheetCmd}" "--paging=always" "--style=plain" "--language=md" "${cheatsheetPath}" {
                      floating true
                      close_on_exit true
                      name "cheatsheet"
                  }
              }
          }
      }
    ''}
  '';
in
{
  options.apps.cli.zellij = {
    enable = lib.mkEnableOption "Zellij terminal multiplexer";

    defaultShell = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.${globals.preferences.shell}}/bin/${globals.preferences.shell}";
      description = ''
        Absolute path to the shell zellij spawns inside new panes.

        Default resolves the package named by globals.preferences.shell
        ("fish") to its store path. Using an absolute path -- rather than
        a name on PATH -- ensures the shell is part of the closure and
        does not depend on the systemd user manager inheriting an
        HM-augmented PATH at start time.
      '';
    };

    tsnetNode = lib.mkOption {
      type = lib.types.str;
      default = "zellij";
      description = "Tailnet node name Caddy joins as for zellij web (URL: https://<node>.<tailnetDomain>/).";
    };

    internalPort = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Loopback port where zellij web listens (proxied by Caddy via tsnet).";
    };

    service.enable = lib.mkEnableOption "zellij web persistent server (systemd user service + Caddy tsnet vhost)";

    mosh.enable = lib.mkEnableOption ''
      Mosh server alongside zellij. Both solve the "remote-dev session
      that survives the network" problem from different layers — mosh
      keeps the transport alive across roaming/sleep/IP changes, zellij
      keeps the multiplexed session alive across reconnects. Together
      they make a headless dev box feel local. Installs `pkgs.mosh` and
      opens UDP 60000-61000 on the firewall'';

    hideStatusBar = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Replace zellij's default layout with a single-pane layout that
        omits both tab-bar and status-bar plugins, freeing those rows
        for content. Pair with `cheatsheet.enable` so you have an
        on-demand keybind reference to make up for the lost hint strip.
      '';
    };

    cheatsheet = {
      enable = lib.mkEnableOption ''
        On-demand zellij keybind reference. Installs a markdown
        cheat sheet to ${cheatsheetPath} and binds a key
        (default `Alt /`) that opens the sheet inside a floating
        zellij pane via `bat --paging=always`. Press `q` to close.
        Designed to coexist with `hideStatusBar = true`'';

      keybind = lib.mkOption {
        type = lib.types.str;
        default = "Alt /";
        example = "F1";
        description = "Zellij KDL keybind string for the cheatsheet floating pane.";
      };

      extraContent = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Additional markdown appended to the bundled cheatsheet, useful
          for host-specific notes (custom abbreviations, ssh hostnames,
          fish functions you keep forgetting, etc.).
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home-manager.users.${globals.user.name} = {
          programs.zellij = {
            enable = true;
            package = pkgs.zellij;
          };

          # Write config.kdl directly rather than via programs.zellij.settings
          # so we can compose keybinds and conditional layout selection
          # without fighting the home-manager KDL serializer.
          xdg.configFile."zellij/config.kdl".text = configKdl;
        };
      }

      (lib.mkIf cfg.mosh.enable {
        environment.systemPackages = [ pkgs.mosh ];
        networking.firewall.allowedUDPPortRanges = [
          {
            from = 60000;
            to = 61000;
          }
        ];
      })

      (lib.mkIf cfg.hideStatusBar {
        home-manager.users.${globals.user.name}.xdg.configFile."zellij/layouts/no-bar.kdl".text =
          noBarLayoutKdl;
      })

      (lib.mkIf cfg.cheatsheet.enable {
        environment.etc."zellij/cheatsheet.md".source = pkgs.writeText "zellij-cheatsheet.md" (
          builtins.readFile ./cheatsheet.md
          + lib.optionalString (cfg.cheatsheet.extraContent != "") ("\n" + cfg.cheatsheet.extraContent)
        );
      })

      (lib.mkIf cfg.service.enable {
        # Required so the user's systemd manager (and therefore the
        # zellij-web user service) starts at boot on headless hosts.
        # Without linger, systemd --user only spawns when the user
        # actively logs in, defeating the "browser-accessible without
        # SSH" promise of the web client.
        users.users.${globals.user.name}.linger = true;

        system.caddy = {
          enable = true;
          tsnetNodes = [ cfg.tsnetNode ];
        };

        services.caddy.virtualHosts."https://${cfg.tsnetNode}.${caddyCfg.tailnetDomain}" = {
          extraConfig = ''
            bind tailscale/${cfg.tsnetNode}
            header {
              # Strip Referer on outbound responses so the bearer token in any
              # initial ?token= URL never leaks to a third-party site clicked
              # from inside the terminal.
              Referrer-Policy "no-referrer"
              # Defense in depth: prevent the zellij origin from being framed
              # by another tsnet vhost and from sourcing arbitrary scripts.
              # zellij-web's own assets are same-origin, so this is safe.
              Content-Security-Policy "frame-ancestors 'none'; form-action 'self'"
              X-Frame-Options "DENY"
            }
            reverse_proxy 127.0.0.1:${toString cfg.internalPort}
          '';
        };

        home-manager.users.${globals.user.name} = {
          systemd.user.services.zellij-web = {
            Unit = {
              Description = "Zellij web client (browser-accessible terminal multiplexer)";
              After = [ "network.target" ];
            };
            Service = {
              ExecStart = lib.concatStringsSep " " [
                "${pkgs.zellij}/bin/zellij"
                "web"
                "--start"
                "--ip 127.0.0.1"
                "--port ${toString cfg.internalPort}"
              ];
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
