{
  pkgs,
  config,
  lib,
  globals,
  ...
}:
let
  cfg = config.apps.cli.homelab-secret-sync;

  # Runs the homelab repo's own sync script, so the list of what gets copied
  # stays in the repo (manifests/base/external-secrets/gopass-map.tsv) and a
  # new ExternalSecret needs no change here. The script reads each secauto entry
  # through a pipe and applies it to the cluster; no value reaches argv, a file
  # or the journal. See homelab docs/flux.md ("Cluster Secrets via External
  # Secrets Operator") and scripts/sync-secauto.sh.
  sync = pkgs.writeShellApplication {
    name = "homelab-secret-sync";
    runtimeInputs = [
      pkgs.gopass
      pkgs.jq
      pkgs.kubectl
      pkgs.git
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = ''
      repo=${lib.escapeShellArg cfg.repoPath}
      script="$repo/scripts/sync-secauto.sh"
      map="manifests/base/external-secrets/gopass-map.tsv"

      if [[ ! -f "$script" ]]; then
        echo "homelab-secret-sync: $script not found. Is the homelab repo cloned at $repo?" >&2
        exit 2
      fi

      # The map and the script decide what reaches the cluster, so run them only
      # from reviewed state: the checkout must be on main and neither file may
      # have local edits. A checkout on a work branch would otherwise sync
      # whatever that branch happens to list.
      branch="$(git -C "$repo" branch --show-current)"
      if [[ "$branch" != "main" ]]; then
        echo "homelab-secret-sync: $repo is on '$branch', not main. Nothing synced." >&2
        exit 1
      fi
      if [[ -n "$(git -C "$repo" status --porcelain -- scripts/sync-secauto.sh "$map")" ]]; then
        echo "homelab-secret-sync: local edits to the sync script or map. Nothing synced." >&2
        exit 1
      fi

      export CLUSTER=${lib.escapeShellArg cfg.cluster}
      export KUBECONFIG=${lib.escapeShellArg cfg.kubeconfig}
      # The script finds the map through `git rev-parse --show-toplevel`, so it
      # has to start inside the repo.
      cd "$repo"
      exec bash "$script"
    '';
  };
in
{
  options.apps.cli.homelab-secret-sync = {
    enable = lib.mkEnableOption ''
      copying the secauto gopass entries listed in the homelab repo's
      gopass-map.tsv into the cluster once a day, so a secret changed on this
      host reaches External Secrets Operator without a manual
      `just workloads::sync-secauto`. Enable it on the host that edits secrets
      (qbert): it needs the secauto gopass store with its GPG key, and a
      kubeconfig for the cluster.

      A failed run leaves the cluster's Secrets as they were (the script checks
      every entry exists before it writes anything) and shows in
      `systemctl --user status homelab-secret-sync` and the journal. If the GPG
      key needs a passphrase that gpg-agent no longer has cached, the run fails
      until the key is unlocked once
    '';

    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "${globals.user.homeDirectory}/git/homelab";
      description = "Primary checkout of the homelab repo. It must be on main with a clean sync script and map.";
    };

    cluster = lib.mkOption {
      type = lib.types.str;
      default = "darkstar";
      description = "Cluster name, passed to the sync script as CLUSTER.";
    };

    kubeconfig = lib.mkOption {
      type = lib.types.str;
      default = "${globals.user.homeDirectory}/.kube/clusters/${cfg.cluster}_kubeconfig";
      description = "Kubeconfig for the cluster. Defaults to where the homelab tofu apply writes it.";
    };

    calendar = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 06:30:00";
      description = "systemd OnCalendar expression for the daily run. Persistent, so a missed run happens at next boot.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ sync ];

    # A user timer, so the sync runs as the user whose gopass store and
    # kubeconfig it needs. The primary user lingers (modules/system/linger), so
    # the user manager is up from boot and this fires with nobody logged in.
    home-manager.users.${globals.user.name} = {
      systemd.user.timers.homelab-secret-sync = {
        Unit.Description = "homelab-secret-sync timer";
        Timer = {
          OnCalendar = cfg.calendar;
          Persistent = true;
          RandomizedDelaySec = "10min";
        };
        Install.WantedBy = [ "timers.target" ];
      };

      systemd.user.services.homelab-secret-sync = {
        Unit.Description = "Copy secauto gopass entries into the homelab cluster";
        Service = {
          Type = "oneshot";
          TimeoutStartSec = "2min";
          ExecStart = "${sync}/bin/homelab-secret-sync";
        };
      };
    };
  };
}
