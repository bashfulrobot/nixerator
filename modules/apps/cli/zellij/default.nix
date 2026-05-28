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

  # `zj` — tight, transparent zellij wrapper. `z` is zoxide, so two
  # letters it is. Four wrapper-aware verbs (s/a/d/n) handle the daily
  # workflow with fzf where it adds value; anything else is passed
  # straight through to `zellij`, so muscle-memory commands like
  # `zj run …`, `zj edit foo.md`, `zj action …` keep working.
  #
  # Bare `zj` deliberately lists sessions instead of running zellij —
  # a self-imposed gate so the user always sees current state and
  # consciously chooses `zj a` (attach) or `zj n <name>` (new named
  # session), avoiding the trap of accidentally spawning unnamed
  # sessions with auto-generated zellij names.
  #
  # `d` is intentionally smart: it always means "make this session go
  # away forever" regardless of whether it's currently active or
  # already exited. `zellij delete-session --force` does kill-then-
  # delete in one call, so the wrapper doesn't need to introspect
  # session status.
  zjFishBody = ''
    function __zj_help
        echo "Usage:"
        echo "  zj                          list sessions (gate: forces conscious next action)"
        echo "  zj s                        list sessions"
        echo "  zj a [<name>]               attach (fzf if no name)"
        echo "  zj d [<name>...]            delete session (fzf if no name; kills active first)"
        echo "  zj n <name>                 new named session (or attach if it exists)"
        echo "  zj n <name> -- <cmd...>     new named session whose first pane runs <cmd>"
        echo "  zj help                     this message"
        echo "  zj <anything else>          passthrough to zellij"
    end

    if test (count $argv) -eq 0
        zellij list-sessions
        return $status
    end

    set -l sub $argv[1]
    set -l rest $argv[2..-1]

    switch "$sub"
        case s ls
            zellij list-sessions $rest

        case a
            if test (count $rest) -gt 0
                zellij attach $rest
                return $status
            end
            set -l active (zellij list-sessions -s 2>/dev/null | string trim)
            if test (count $active) -eq 0
                echo "zj: no sessions to attach to" >&2
                return 1
            end
            if not type -q fzf
                echo "zj: install fzf or pass a session name" >&2
                return 2
            end
            set -l picked (printf '%s\n' $active | fzf --prompt='attach> ' --height=40% --border)
            if test -z "$picked"
                return 130
            end
            zellij attach $picked

        case d
            if test (count $rest) -gt 0
                for s in $rest
                    zellij delete-session --force $s
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
            set -l picked (printf '%s\n' $all | fzf --multi --prompt='delete> ' --height=40% --border --header='Tab to multi-select; kills active first')
            if test -z "$picked"
                return 130
            end
            for s in $picked
                zellij delete-session --force $s
            end

        case n
            if test (count $rest) -eq 0
                echo "zj n: requires a session name" >&2
                return 2
            end
            set -l name $rest[1]
            set -l have_cmd 0
            set -l cmd_args
            if test (count $rest) -ge 2
                if test "$rest[2]" = '--'
                    set have_cmd 1
                    if test (count $rest) -ge 3
                        set cmd_args $rest[3..-1]
                    end
                else
                    echo "zj n: extra arguments require '--' separator (got: $rest[2..-1])" >&2
                    return 2
                end
            end

            if test $have_cmd -eq 0
                # attach -c: create if missing, attach if exists. Friendliest
                # "give me this session" behavior.
                zellij attach -c $name
                return $status
            end

            if test (count $cmd_args) -eq 0
                echo "zj n: '--' requires a command" >&2
                return 2
            end

            # Refuse to clobber an existing session — `--session` would
            # conflict with an existing name. With `-- <cmd>` the user is
            # explicitly asking for a fresh session, so attach-if-exists
            # would silently ignore their command.
            if zellij list-sessions -s 2>/dev/null | string match -q -- $name
                echo "zj n: session '$name' already exists; \`zj a $name\` to attach, or \`zj d $name\` first" >&2
                return 1
            end

            # Build a one-pane layout that runs the joined command via
            # `sh -c`, so the user can supply pipelines / redirects without
            # the wrapper having to teach KDL each argv element. Quotes
            # inside the joined string need KDL escaping (just `"`).
            set -l cmd_str (string join ' ' -- $cmd_args)
            set -l cmd_escaped (string replace -a '"' '\\"' -- $cmd_str)

            # In zellij 0.44, `--session NEW --layout-string …` is interpreted
            # as "append tabs to existing session NEW" and fails with "Session
            # 'NEW' not found" when NEW doesn't exist yet. The only flag that
            # reliably starts a fresh session is --new-session-with-layout,
            # which requires a file path. Stage the KDL to a tempfile, then
            # clean up after zellij exits (the layout is consumed at session
            # creation and not needed afterwards).
            #
            # KDL must be multi-line: single-line `{ args "-c" "…" }` fails
            # zellij's parser ("Failed to deserialize KDL node") because nodes
            # inside a block need newline or `;` termination.
            set -l layout_file (mktemp --suffix=.kdl)
            printf '%s\n' \
                'layout {' \
                '    pane command="sh" {' \
                "        args \"-c\" \"$cmd_escaped\"" \
                '    }' \
                '}' > $layout_file
            zellij --session $name --new-session-with-layout $layout_file
            set -l rc $status
            rm -f $layout_file
            return $rc

        case -h --help help
            __zj_help

        case '*'
            zellij $argv
    end
  '';

  # `czj` — "c" for claude, layered on `zj`. One command launches a
  # zellij session, a local interactive Claude in that pane, and a
  # Remote Control registration, all sharing the same name. Phone or
  # browser at claude.ai/code can then join the same live conversation
  # without taking the terminal away from the local user (per `claude`
  # docs, the `--remote-control` *flag* keeps both surfaces alive; only
  # the `claude remote-control` *subcommand* claims the TTY).
  #
  # Bare `czj` mirrors `zj`'s "list and force a conscious next step"
  # gate by delegating straight to `zj`, so there is one place that
  # owns session-listing UX. With one argument it validates the name
  # before any side effect, attaches if a zellij session of that name
  # already exists (since `zj n NAME -- cmd` would refuse to clobber),
  # and otherwise hands the launch to `zj n` so layout / session-name
  # plumbing stays in one wrapper.
  czjFishBody = ''
    function __czj_help
        echo "Usage:"
        echo "  czj                       list sessions (delegates to zj)"
        echo "  czj <name>                create-or-attach zellij session <name>"
        echo "                            running: claude -n <name> --remote-control <name>"
        echo "  czj d [<name>...]         delete czj-made session(s): zellij + on-disk Claude"
        echo "                            transcript. With no name, fzf picker."
        echo "  czj help                  this message"
        echo ""
        echo "Names must match [A-Za-z0-9._-]+ and not start with '-'."
    end

    # Print absolute paths of ~/.claude/projects/*/*.jsonl whose customTitle
    # exactly equals NAME. Match is on the encoded JSON form
    # `"customTitle":"NAME"` -- names are pre-validated to [A-Za-z0-9._-]+
    # so no JSON escaping is needed and shell-injection into `grep` is not
    # reachable. -F = fixed string, -l = list matching files.
    function __czj_find_transcripts -a name
        grep -lF --include='*.jsonl' -r -- "\"customTitle\":\"$name\"" \
            ~/.claude/projects/ 2>/dev/null
    end

    # Union of live zellij session names and on-disk czj transcript names.
    # Used by the bare `czj d` fzf picker.
    function __czj_candidates
        set -l zellij_names (zellij list-sessions -s 2>/dev/null)
        set -l disk_names (grep -hoE '"customTitle":"[^"]+"' \
            --include='*.jsonl' -r ~/.claude/projects/ 2>/dev/null \
            | sed -E 's/.*"customTitle":"([^"]+)".*/\1/')
        printf '%s\n' $zellij_names $disk_names | sort -u
    end

    # Per-name cleanup: validate, delete zellij side via `zj d`, remove
    # matching on-disk JSONL(s) and sibling uuid dirs. Prints per-step
    # status with the NAME as a prefix so multi-name runs stay legible.
    function __czj_delete_one -a name
        if not string match -rq -- '^[A-Za-z0-9._-]+$' $name
            echo "czj d: invalid name '$name'; only [A-Za-z0-9._-] allowed" >&2
            return 2
        end
        if string match -q -- '-*' $name
            echo "czj d: name cannot start with '-' (got '$name')" >&2
            return 2
        end

        set -l overall 0

        # Zellij side. `zj d` runs `zellij delete-session --force`, which
        # works whether the session is alive or already exited. On a live
        # session the SIGHUP from teardown lets Claude's shutdown handler
        # run, which deregisters Remote Control as a free side-effect.
        if zellij list-sessions -s 2>/dev/null | string match -q -- $name
            zj d $name
            set -l rc $status
            if test $rc -ne 0
                echo "czj d $name: zellij delete failed (exit $rc)" >&2
                set overall $rc
            else
                echo "czj d $name: zellij session deleted"
            end
        else
            echo "czj d $name: no zellij session named '$name'"
        end

        # On-disk Claude side. A name can match multiple JSONLs if `czj
        # NAME` was run from different cwds historically; remove all
        # matches. Sibling <uuid>/ directory (tool-results sidecar) is
        # derived by stripping `.jsonl` from the path.
        set -l files (__czj_find_transcripts $name)
        if test (count $files) -eq 0
            echo "czj d $name: no on-disk transcript with customTitle='$name'"
        else
            for f in $files
                set -l dir (string replace -r '\.jsonl$' "" -- $f)
                rm -f -- $f
                set -l rc1 $status
                rm -rf -- $dir
                set -l rc2 $status
                if test $rc1 -ne 0 -o $rc2 -ne 0
                    echo "czj d $name: failed to remove $f or $dir" >&2
                    set overall 1
                else
                    echo "czj d $name: transcript $f removed (and sibling dir)"
                end
            end
        end

        return $overall
    end

    # `czj d` dispatcher. With names: loop, continue on per-name error,
    # return last non-zero. Without names: fzf picker over candidates.
    function __czj_delete
        if test (count $argv) -eq 0
            set -l candidates (__czj_candidates)
            if test (count $candidates) -eq 0
                echo "czj d: nothing to delete (no zellij sessions, no on-disk transcripts)" >&2
                return 1
            end
            if not type -q fzf
                echo "czj d: install fzf or pass a name" >&2
                return 2
            end
            set -l picked (printf '%s\n' $candidates \
                | fzf --multi --prompt='czj delete> ' --height=40% --border \
                      --header='Tab to multi-select; deletes zellij + on-disk transcript')
            if test -z "$picked"
                return 130
            end
            set -l rc 0
            for name in $picked
                __czj_delete_one $name
                set -l one $status
                if test $one -ne 0
                    set rc $one
                end
            end
            return $rc
        end

        set -l rc 0
        for name in $argv
            __czj_delete_one $name
            set -l one $status
            if test $one -ne 0
                set rc $one
            end
        end
        return $rc
    end

    if test (count $argv) -eq 0
        zj
        return $status
    end

    set -l sub $argv[1]
    set -l rest $argv[2..-1]

    switch "$sub"
        case -h --help help
            __czj_help
            return 0
        case d
            __czj_delete $rest
            return $status
    end

    # Fallthrough: $sub is treated as a session name (the existing
    # `czj NAME` shape). Reject extra positional args here so the
    # "takes 0 or 1 argument" contract for the create-or-attach path
    # is preserved; sub-verbs (`d`) have their own arity rules above.
    if test (count $argv) -gt 1
        echo "czj: takes 0 or 1 argument for create-or-attach (got: $argv); did you mean `czj d $argv`?" >&2
        return 2
    end

    set -l name $sub

    # Validate before doing anything. zellij and claude both choke on
    # whitespace and shell-special chars in session names, and a
    # leading dash gets parsed as a flag by one of the inner commands.
    # Fail fast with a clear message instead of letting the failure
    # surface three layers deep.
    if not string match -rq -- '^[A-Za-z0-9._-]+$' $name
        echo "czj: invalid name '$name'; only [A-Za-z0-9._-] allowed" >&2
        return 2
    end
    if string match -q -- '-*' $name
        echo "czj: name cannot start with '-' (got '$name')" >&2
        return 2
    end

    # `zj n NAME -- cmd` refuses to clobber an existing session, so we
    # have to short-circuit here: if the session already exists, just
    # attach. There is presumably already a Claude running in it
    # (started by an earlier `czj NAME`); a second one would conflict
    # on the Remote Control session name anyway.
    if zellij list-sessions -s 2>/dev/null | string match -q -- $name
        zellij attach $name
        return $status
    end

    # Three places, one name:
    #   - zellij session  : `zj n NAME`             (visible in `zj`, terminal title)
    #   - claude local    : `-n NAME`               (prompt box, /resume picker)
    #   - remote control  : `--remote-control NAME` (claude.ai/code, iOS app)
    zj n $name -- claude -n $name --remote-control $name
  '';

  # Fish completions for `czj`. Same lazy-load pattern as `zj.fish`.
  # Only the first positional arg gets suggestions: existing sessions
  # (so `czj <Tab>` offers attach targets); -f suppresses the file
  # fallback fish would otherwise add.
  czjCompletions = ''
    function __czj_sessions
        zellij list-sessions -s 2>/dev/null
    end

    # Mirrors __czj_candidates in czjFishBody, duplicated here because
    # completions are sourced at fish startup, before the `czj` function
    # body has ever run (so the body-local helpers aren't defined yet).
    function __czj_candidates_complete
        set -l zellij_names (zellij list-sessions -s 2>/dev/null)
        set -l disk_names (grep -hoE '"customTitle":"[^"]+"' \
            --include='*.jsonl' -r ~/.claude/projects/ 2>/dev/null \
            | sed -E 's/.*"customTitle":"([^"]+)".*/\1/')
        printf '%s\n' $zellij_names $disk_names | sort -u
    end

    complete -c czj -f
    complete -c czj -n __fish_use_subcommand -a help -d 'show usage'
    complete -c czj -n __fish_use_subcommand -a d    -d 'delete czj-made session(s): zellij + on-disk Claude transcript'
    complete -c czj -n __fish_use_subcommand -a '(__czj_sessions)' -d 'attach if exists; else create + claude --remote-control'
    complete -c czj -n '__fish_seen_subcommand_from d' -f -a '(__czj_candidates_complete)'
  '';

  # Fish completions for `zj` itself. Lives under
  # `~/.config/fish/completions/zj.fish` so fish lazy-loads it the first
  # time the user tabs `zj`.
  zjCompletions = ''
    function __zj_sessions
        zellij list-sessions -s 2>/dev/null
    end

    complete -c zj -f
    complete -c zj -n __fish_use_subcommand -a s    -d 'list sessions'
    complete -c zj -n __fish_use_subcommand -a a    -d 'attach (fzf if no name)'
    complete -c zj -n __fish_use_subcommand -a d    -d 'delete session (fzf if no name; kills active first)'
    complete -c zj -n __fish_use_subcommand -a n    -d 'new named session (or attach if it exists)'
    complete -c zj -n __fish_use_subcommand -a help -d 'show usage'
    complete -c zj -n '__fish_seen_subcommand_from a' -f -a '(__zj_sessions)'
    complete -c zj -n '__fish_seen_subcommand_from d' -f -a '(__zj_sessions)'
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
          programs.fish.functions.czj = {
            description = "claude + zellij launcher: zellij/claude/RC sessions all share one name";
            body = czjFishBody;
          };
          xdg.configFile."fish/completions/zj.fish".text = zjCompletions;
          xdg.configFile."fish/completions/czj.fish".text = czjCompletions;
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
