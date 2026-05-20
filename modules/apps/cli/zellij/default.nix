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

  # `zj` — short, ergonomic zellij wrapper. `z` is zoxide, so two letters
  # it is. Replaces the missing dynamic tab-completion for kill-session /
  # delete-session with fzf pickers, plus a no-arg attach picker. Anything
  # not recognized is passed through, so muscle-memory commands like
  # `zj run …`, `zj setup --dump-layout`, etc. still work.
  zjFishBody = ''
    function __zj_help
        echo "Usage: zj [SUBCOMMAND] [args]"
        echo ""
        echo "  zj                    pick an active session (fzf), attach"
        echo "  zj <name>             attach to <name>, create if missing"
        echo "  zj ls                 list sessions"
        echo "  zj kill [<name>...]   kill active session (fzf if omitted, Tab=multi)"
        echo "  zj del  [<name>...]   delete session (fzf if omitted, Tab=multi)"
        echo "  zj clean              delete-all-sessions (bulk exited cleanup)"
        echo "  zj nuke               kill all active + delete all (confirm)"
        echo "  zj help               this message"
        echo "  zj <anything else>    passthrough to zellij"
    end

    set -l sub $argv[1]
    set -l rest $argv[2..-1]

    switch "$sub"
        case '''
            set -l active (zellij list-sessions -s 2>/dev/null | string trim)
            if test (count $active) -eq 0
                echo "zj: no active sessions, starting a new one"
                zellij
                return $status
            end
            set -l picked
            if type -q fzf
                set picked (printf '%s\n' $active | fzf --prompt='attach> ' --height=40% --border)
            else
                for i in (seq (count $active))
                    echo "$i) $active[$i]"
                end
                read -P 'Pick #: ' -l idx
                if string match -qr '^[0-9]+$' -- $idx
                    if test $idx -ge 1 -a $idx -le (count $active)
                        set picked $active[$idx]
                    end
                end
            end
            if test -z "$picked"
                return 130
            end
            zellij attach -c $picked

        case ls list list-sessions
            zellij list-sessions $rest

        case kill kill-session
            if test (count $rest) -gt 0
                for s in $rest
                    zellij kill-session $s
                end
                return $status
            end
            set -l active (zellij list-sessions -s 2>/dev/null | string trim)
            if test (count $active) -eq 0
                echo "zj: no active sessions to kill" >&2
                return 1
            end
            if not type -q fzf
                echo "zj: install fzf or pass a session name" >&2
                return 2
            end
            set -l picked (printf '%s\n' $active | fzf --multi --prompt='kill> ' --height=40% --border --header='Tab to multi-select')
            if test -z "$picked"
                return 130
            end
            for s in $picked
                zellij kill-session $s
            end

        case del delete delete-session
            if test (count $rest) -gt 0
                for s in $rest
                    zellij delete-session $s
                end
                return $status
            end
            set -l all (zellij list-sessions -s 2>/dev/null | string trim)
            if test (count $all) -eq 0
                echo "zj: no sessions to delete" >&2
                return 1
            end
            if not type -q fzf
                echo "zj: install fzf or pass a session name" >&2
                return 2
            end
            set -l picked (printf '%s\n' $all | fzf --multi --prompt='delete> ' --height=40% --border --header='Tab to multi-select')
            if test -z "$picked"
                return 130
            end
            for s in $picked
                zellij delete-session $s
            end

        case clean delete-all delete-all-sessions
            zellij delete-all-sessions --yes

        case nuke
            read -P 'zj: kill ALL active and delete ALL sessions? [y/N] ' -l ans
            if not string match -qi 'y*' -- $ans
                return 130
            end
            for s in (zellij list-sessions -s 2>/dev/null | string trim)
                zellij kill-session $s 2>/dev/null
            end
            zellij delete-all-sessions --yes

        case -h --help help
            __zj_help

        case '*'
            zellij $argv
    end
  '';

  # Fish completions for `zj` itself. Lives under
  # `~/.config/fish/completions/zj.fish` so fish lazy-loads it the first
  # time the user tabs `zj`.
  zjCompletions = ''
    function __zj_sessions
        zellij list-sessions -s 2>/dev/null
    end

    complete -c zj -f
    complete -c zj -n __fish_use_subcommand -a ls    -d 'list sessions'
    complete -c zj -n __fish_use_subcommand -a kill  -d 'kill active session (fzf if no name)'
    complete -c zj -n __fish_use_subcommand -a del   -d 'delete session (fzf if no name)'
    complete -c zj -n __fish_use_subcommand -a clean -d 'delete-all-sessions'
    complete -c zj -n __fish_use_subcommand -a nuke  -d 'kill + delete all (confirm)'
    complete -c zj -n __fish_use_subcommand -a help  -d 'show usage'
    complete -c zj -n __fish_use_subcommand -a '(__zj_sessions)' -d session
    complete -c zj -n '__fish_seen_subcommand_from kill kill-session' -f -a '(__zj_sessions)'
    complete -c zj -n '__fish_seen_subcommand_from del delete delete-session' -f -a '(__zj_sessions)'
  '';

  # Dynamic session-name completion for the native `zellij` subcommands
  # whose value slots zellij's shipped fish completions leave empty
  # (attach, kill-session, delete-session and their k/a/d aliases).
  #
  # MUST live in `conf.d/`, not `completions/zellij.fish`:
  #   * `completions/zellij.fish` would REPLACE the vendor completion file
  #     shipped by the zellij package (fish's completion-file lookup picks
  #     one file by precedence, not multiple), losing every subcommand and
  #     flag.
  #   * `conf.d/*.fish` is sourced at fish startup and the `complete -c
  #     zellij ...` lines it contains just add to the rule set, layering on
  #     top of whatever the vendor completion file later registers.
  #
  # `-f` is required: zellij's shipped completions don't constrain the
  # value slot, so without `-f` fish falls back to file/folder completion
  # (the bug this was originally written for). With `-f`, file fallback
  # is suppressed only when these conditions match; `zellij run -- <path>`
  # etc. is unaffected.
  zellijAugmentCompletions = ''
    function __zj_sessions
        zellij list-sessions -s 2>/dev/null
    end

    complete -c zellij -n '__fish_seen_subcommand_from attach a'         -f -a '(__zj_sessions)'
    complete -c zellij -n '__fish_seen_subcommand_from kill-session k'   -f -a '(__zj_sessions)'
    complete -c zellij -n '__fish_seen_subcommand_from delete-session d' -f -a '(__zj_sessions)'
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

      # `zj` fish wrapper + augmented zellij completions. No user-facing
      # gate: enabled whenever zellij and fish are both on. If fish is off,
      # silently skip so the zellij module stays usable in non-fish hosts.
      (lib.mkIf config.apps.cli.fish.enable {
        home-manager.users.${globals.user.name} = {
          programs.fish.functions.zj = {
            description = "zellij wrapper with fzf-driven session pickers";
            body = zjFishBody;
          };
          xdg.configFile."fish/completions/zj.fish".text = zjCompletions;
          xdg.configFile."fish/conf.d/zellij-augment.fish".text = zellijAugmentCompletions;
        };
      })

      (lib.mkIf cfg.service.enable {
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
