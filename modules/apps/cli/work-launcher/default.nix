{
  lib,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.cli.work-launcher;

  # Render peers as a space-separated, double-quoted fish list literal so
  # the function body can do `set -l peers $peersList` without further
  # parsing. Hostnames don't contain spaces, but quoting is cheap insurance.
  peersFishList = lib.concatMapStringsSep " " (p: ''"${p}"'') cfg.peers;
in
{
  options.apps.cli.work-launcher = {
    enable = lib.mkEnableOption "work fish function for cross-host zellij session attach";

    peers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "srv"
        "qbert"
      ];
      description = ''
        Hostnames the `work` fish function probes for zellij sessions
        when resolving an unqualified `work <name>` invocation, and when
        building the no-argument picker. The current host (matched at
        runtime via the `hostname` command) is automatically skipped on
        the SSH leg — local sessions are listed via `zellij list-sessions`
        directly.
      '';
    };

    sshUser = lib.mkOption {
      type = lib.types.str;
      default = globals.user.name;
      description = ''
        SSH user the launcher connects to peers as. Defaults to
        globals.user.name (single-user hosts under this flake).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      programs.fish.functions.work = {
        description = "Attach to (or create) a zellij session across peer hosts";
        body = ''
          # Build-time configuration injected by the work-launcher module.
          set -l peers ${peersFishList}
          set -l ssh_user ${cfg.sshUser}
          set -l current_host (hostname)

          # --- arg parsing ---
          set -l force_local 0
          set -l name ""
          for arg in $argv
              switch $arg
                  case '--here'
                      set force_local 1
                  case '-h' '--help'
                      echo "Usage: work [--here] [<name>[@<host>]]"
                      echo ""
                      echo "  work                  pick a session across peers, attach"
                      echo "  work <name>           attach to <name>; create on current host if not found"
                      echo "  work <name>@<host>    attach to <name> on specific <host>"
                      echo "  work --here <name>    force current host"
                      return 0
                  case '*'
                      set name $arg
              end
          end

          # Refuse to nest zellij.
          if set -q ZELLIJ
              echo "work: already inside a zellij session. Detach first (Ctrl-q q)." >&2
              return 2
          end

          # Explicit <name>@<host> form short-circuits discovery.
          if string match -q '*@*' -- $name
              set -l parts (string split -m1 '@' -- $name)
              set name $parts[1]
              set -l target $parts[2]
              if test "$target" = "$current_host"
                  zellij attach -c $name
                  return $status
              end
              ssh -t -o ConnectTimeout=2 $ssh_user@$target -- zellij attach -c $name
              return $status
          end

          # --here forces local even if a peer has the name.
          if test $force_local -eq 1
              if test -z "$name"
                  echo "work --here requires a <name>" >&2
                  return 2
              end
              zellij attach -c $name
              return $status
          end

          # Local sessions snapshot.
          set -l local_sessions
          if type -q zellij
              set local_sessions (zellij list-sessions -s 2>/dev/null | string trim)
          end

          # If a name was given and exists locally, attach immediately.
          if test -n "$name"
              if contains -- $name $local_sessions
                  zellij attach -c $name
                  return $status
              end
          end

          # Probe peers (skip current host).
          set -l inventory_hosts
          set -l inventory_sessions
          for s in $local_sessions
              set inventory_hosts $inventory_hosts $current_host
              set inventory_sessions $inventory_sessions $s
          end
          for peer in $peers
              if test "$peer" = "$current_host"
                  continue
              end
              set -l remote (ssh -o ConnectTimeout=2 -o BatchMode=yes $ssh_user@$peer zellij list-sessions -s 2>/dev/null | string trim)
              for s in $remote
                  set inventory_hosts $inventory_hosts $peer
                  set inventory_sessions $inventory_sessions $s
              end
          end

          # Name given: find first peer match.
          if test -n "$name"
              for i in (seq (count $inventory_sessions))
                  if test "$inventory_sessions[$i]" = "$name"
                      set -l target $inventory_hosts[$i]
                      if test "$target" = "$current_host"
                          zellij attach -c $name
                      else
                          ssh -t -o ConnectTimeout=2 $ssh_user@$target -- zellij attach -c $name
                      end
                      return $status
                  end
              end
              echo "work: no session '$name' found across peers ($peers), creating on $current_host" >&2
              zellij attach -c $name
              return $status
          end

          # No name: present picker.
          set -l n (count $inventory_sessions)
          if test $n -eq 0
              echo "work: no zellij sessions found on any peer ($peers)" >&2
              return 1
          end

          set -l choices
          for i in (seq $n)
              set choices $choices "$inventory_sessions[$i]  ($inventory_hosts[$i])"
          end

          set -l picked_idx
          if type -q fzf
              set -l picked (printf '%s\n' $choices | fzf --prompt="session> " --height=40%)
              if test -z "$picked"
                  return 130
              end
              for i in (seq $n)
                  if test "$choices[$i]" = "$picked"
                      set picked_idx $i
                      break
                  end
              end
          else
              for i in (seq $n)
                  echo "$i) $choices[$i]"
              end
              read -P "Pick #: " idx
              if not string match -qr '^[0-9]+$' -- $idx
                  return 130
              end
              if test $idx -lt 1 -o $idx -gt $n
                  return 130
              end
              set picked_idx $idx
          end

          set -l picked_session $inventory_sessions[$picked_idx]
          set -l picked_host $inventory_hosts[$picked_idx]
          if test "$picked_host" = "$current_host"
              zellij attach -c $picked_session
          else
              ssh -t -o ConnectTimeout=2 $ssh_user@$picked_host -- zellij attach -c $picked_session
          end
          return $status
        '';
      };
    };
  };
}
