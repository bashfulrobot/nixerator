{
  lib,
  pkgs,
  config,
  secrets,
  secretsLib,
  globals,
  ...
}:

let
  # server.nanoclaw's secrets come from the nixerator 1Password vault like the
  # rest of the repo: `just render-secrets` writes them to secrets.json, and an
  # activation script per secret (secretsLib.installValue) copies each to a
  # root-only file under /run/nanoclaw-secrets. Eval only checks that a key
  # exists, never its value. Until the core keys exist the service stays off and
  # eval warns, so srv keeps building in the meantime.
  nanoclawSecretsDir = "/run/nanoclaw-secrets";
  nanoclawSecrets = {
    claude-token = "claudeToken";
    onecli-db-password = "onecliDbPassword";
  };

  # The Slack channel's two tokens, gated the same way but separately: the
  # assistant can run terminal-only before these exist.
  nanoclawSlackSecrets = {
    slack-bot-token = "slackBotToken";
    slack-app-token = "slackAppToken";
  };
  hasNanoclawKeys =
    set: lib.all (key: lib.hasAttrByPath [ "nanoclaw" key ] secrets) (lib.attrValues set);
  nanoclawReady = hasNanoclawKeys nanoclawSecrets;
  nanoclawSlackReady = nanoclawReady && hasNanoclawKeys nanoclawSlackSecrets;

  nanoclawSecretPath = name: "${nanoclawSecretsDir}/${name}";
  installNanoclawSecret =
    name: key:
    secretsLib.installValue {
      jq = "${pkgs.jq}/bin/jq";
      secretsFile = secretsLib.file globals;
      path = ".nanoclaw.${key}";
      dest = nanoclawSecretPath name;
      mode = "0400";
    };
in
{
  # Import only modules that srv used in nixcfg, plus the cherry-picked
  # Claude Code + zellij stack.
  imports = [
    ../../modules/apps/cli/agent-scan
    ../../modules/apps/cli/antigravity
    ../../modules/apps/cli/claude-code
    ../../modules/apps/cli/fish
    ../../modules/apps/cli/gcmt
    ../../modules/apps/cli/fresh-editor
    ../../modules/apps/cli/git
    ../../modules/apps/cli/happy
    ../../modules/apps/cli/helix
    ../../modules/apps/cli/opencode
    ../../modules/apps/cli/render-secrets
    ../../modules/apps/cli/restic
    ../../modules/apps/cli/secauto-pull
    ../../modules/apps/cli/skillfish
    ../../modules/apps/cli/slack-token-refresh
    ../../modules/apps/cli/starship
    ../../modules/apps/cli/superpowers
    ../../modules/apps/cli/syncthing
    ../../modules/apps/cli/tailscale
    ../../modules/apps/cli/text-polish
    ../../modules/apps/cli/todoist-cli
    ../../modules/apps/cli/work-launcher
    ../../modules/apps/cli/zellij
    ../../modules/archetypes/claudeWorkHost
    ../../modules/server/automations
    ../../modules/server/claudoist
    ../../modules/server/incident-investigator
    ../../modules/server/kvm
    ../../modules/server/nanoclaw
    ../../modules/server/nfs
    ../../modules/server/node-exporter
    ../../modules/server/postgres
    # Host-wide invariant, not a feature: declares users.users.<name>.linger so
    # systemd.user timers are scheduled from boot. Workstations get it from
    # ../../modules; srv imports by hand, so it needs the path spelled out.
    # lib/mkHost.nix asserts every host reaches it. Import it from exactly one
    # place per host: a second import path is a second module key, which
    # evaluates the module twice and duplicates its After= entry.
    ../../modules/system/linger
    ../../modules/system/resilient-boot
    ../../modules/system/ssh
  ];

  # Adopts the Claude work-host archetype: zellij + mosh via system.ssh,
  # sshd, work-launcher. Sessions live on srv until killed; attach from
  # anywhere on the tailnet via `work` or `ssh srv zellij attach`.
  archetypes.claudeWorkHost.enable = true;

  # CLI applications (matching nixcfg srv)
  apps.cli = {
    fish.enable = true;
    fresh-editor.enable = true;
    git.enable = true;
    # Ctrl+G in Claude Code offers to polish the prompt. No keybind: srv has no
    # compositor, so only the editor wrapper, not `text-polish.enable`.
    text-polish.editor.enable = true;
    # Mobile/web remote control for Claude Code sessions (happy.engineering).
    # srv is always-on, the natural pairing target alongside qbert.
    happy.enable = true;
    helix.enable = true;
    # media-rename (dlm/dltv) removed 2026-07-31: manual filebot-based
    # seedbox-pull-and-rename, superseded by the k8s download-sync CronJob +
    # Sonarr/Radarr import pipeline, and its mediaRoot
    # (/home/dustin/data-disk/media) was the other half of the dual-mount
    # that corrupted a directory on the media disk -- see
    # hardware-configuration.nix.
    # opencode CLI agent + its LSP language servers (kotlin-lsp/yaml-schema-router
    # are already built for helix above, so no extra closure). Points at cloud
    # models by default; srv has no local Ollama provider wiring (qbert-only).
    opencode = {
      enable = true;
      # Model served by qbert's Ollama over Tailscale. srv has no GPU, so the
      # provider only works while qbert is up.
      remoteOllama = {
        enable = true;
        host = globals.hosts.qbert.tailscale_ip;
        model = globals.ai.localCodeModel;
      };
    };
    # srv renders its own secrets and document-backed files (feral-arr
    # download-sync key, incus cert, filebot license) from the secauto gopass
    # snapshot. Automation never depends on 1Password, so opSupport stays off and
    # `op` is not on the PATH here; see extras/docs/secrets.md.
    render-secrets.enable = true;
    # Reader for the secauto encrypted gopass store: pulls over a read-only
    # deploy key every 15 min. Needs the one-time clone, GPG key import and
    # deploy key described on the option.
    secauto-pull = {
      enable = true;
      # srv renders its secrets file from gopass after every pull, so it needs
      # no 1Password CLI, service-account token or human for routine refreshes.
      renderAfterPull = true;
      # Merge only commits signed with Dustin's SSH signing key. qbert's gopass
      # commits are signed by that identity (git module: commit.gpgsign), so the
      # file holds the same public key the git module publishes.
      allowedSignersFile = toString (
        pkgs.writeText "secauto-allowed-signers" ''
          ${globals.user.email} ${globals.git.gitPubSigningKey}
        ''
      );
    };
    # Extracts Slack xoxc/xoxd session cookies via a persistent Chromium
    # profile (Playwright) so the slack-post skill can send from srv.
    # Separate credential path from claudoist's Slack MCP (Task 1/3-4 of
    # this plan) -- this one backs slack-tracker/slack-post's direct Web
    # API calls, not the MCP tools. First login needs a real browser
    # window (ssh -X srv, then `slack-token-refresh`); after that the
    # persistent profile lets `slack-token-refresh --headless` refresh it
    # without one. Mirrors qbert's enablement via
    # suites.offcomms, cherry-picked here the same way this file already
    # cherry-picks individual apps.cli entries for headless srv.
    slack-token-refresh.enable = true;
    starship.enable = true;
    # Shares ~/automations with qbert (which relays to the Mac) so job reports
    # written here reach every workstation. Two-step rollout: after the first
    # rebuild, read srv's device ID from the Syncthing UI and add it as
    # `syncthing_id` under hosts.srv in settings/globals.nix, then rebuild qbert.
    syncthing = {
      enable = true;
      host.srv = true;
    };
    tailscale.enable = true;
    # `td` for interactive use on srv. The token comes from the secauto gopass
    # store (todoist/credential) at each launch, so no `td auth login` is needed.
    todoist-cli.enable = true;

    # Claude Code stack (cherry-picked from suites/ai for headless srv)
    agent-scan.enable = true;
    antigravity.enable = true;
    claude-code = {
      enable = true;
      serverProfile = "minimal";
      # claude-skills owns the declared settings keys here too: one
      # `claude_stack.py apply` call at activation, the resolved srv file read
      # out of the flake input, and the two shared files written from
      # claude-stack/files/. Rollback and the per-key ownership table:
      # .claude/docs/claude-stack-apply.md.
      stackApply.enable = true;
      # Headless srv runs a SMALLER plugin set than the workstations (no
      # kong CS tooling, gitops, or hyperframes' browser stack). Which plugins
      # and marketplaces it gets comes from the srv claude-stack snapshot
      # (cfg/claude-stack/srv.json, see cfg/plugin-config.nix), not a list
      # here. Edit claude-stack.json in claude-skills to change it; the prune
      # history and rationale are in git history of this file and in
      # .claude/docs/claude-plugins.md.
    };
    skillfish.enable = true;
    superpowers.enable = true;
  };

  # Tailscale subnet router: advertise the home LAN so qbert
  # can reach k8s VM IPs (192.168.168.x) via the tailnet when off the
  # physical LAN. Once applied, approve the route in the Tailscale admin
  # console (or via ACL autoApprovers). useRoutingFeatures="server" enables
  # IP forwarding and the firewall bypass; forwarded packets reach VMs
  # directly over br0 (a true bridge, unlike the old Incus macvlan setup,
  # has no sibling-device/policy-routing workaround to worry about).
  services.tailscale = {
    useRoutingFeatures = "server";
    extraSetFlags = [ "--advertise-routes=192.168.168.0/23" ];
  };

  # System modules. One `system` attrset rather than three dotted paths
  # scattered through the file, which reads as a repeated key.
  system = {
    # Note: this is unrelated to the self-hosted netboot.xyz admin UI that
    # used to live at `server.netbootXyz` (archived, unused). This enables the
    # systemd-boot loader's own netboot.xyz menu entry (chainloads netboot.xyz
    # over the network), one of three features under system.resilient-boot.
    resilient-boot.enable = true;

    # ssh-agent is managed by `keychain` (see hosts/srv/home.nix) so it
    # persists across SSH sessions on this headless box. Do NOT also set
    # `programs.ssh.startAgent` — that would spawn a per-session agent
    # and defeat keychain's single-agent model.
    ssh.enable = true;

    # Materialises the GitHub access token read by the nix.extraOptions
    # `!include` further down. The runtime dir is created by installValue's
    # own `mkdir -p`; a systemd.tmpfiles rule would not help because tmpfiles
    # is applied by a systemd unit that only runs after activation scripts.
    activationScripts.nixAccessToken = lib.stringAfter [ "etc" ] (
      secretsLib.installValue {
        jq = "${pkgs.jq}/bin/jq";
        secretsFile = secretsLib.file globals;
        path = ".github.accessToken";
        dest = "/run/nixos-secrets/nix-access-tokens.conf";
        mode = "0600";
        prefix = "access-tokens = github.com=";
        suffix = "\n";
      }
    );
  };

  # Server-specific modules
  server = {
    # Daily heartbeat report into the synced ~/automations folder. First job on
    # the shared scheduling pattern; real jobs (Slack follow-ups) come later.
    automations = {
      enable = true;
      # Todoist filters kept one per file under modules/server/automations/queries/
      # and run on their own schedule. Reports land in reports/srv/td-<name>/.
      tdQueries = {
        # P1 tasks in kong-* projects with no update, comment or other
        # activity in 2 days. Weekday mornings.
        kong-p1-idle = {
          file = ../../modules/server/automations/queries/kong-p1-idle.filter;
          schedule = "Mon..Fri *-*-* 06:00:00";
          idleDays = 2;
          # Also write an idle-flag worklog comment on each idle task, at most
          # once a week per task. These are real writes to Todoist.
          flagRepeatDays = 7;
        };

        # P2: idle 5 days, checked Monday and Thursday, comment again after 14
        # days. Filter fetch limit raised so a long list is not cut off.
        kong-p2-idle = {
          file = ../../modules/server/automations/queries/kong-p2-idle.filter;
          schedule = "Mon,Thu *-*-* 06:00:00";
          limit = 300;
          idleDays = 5;
          flagRepeatDays = 14;
        };

        # P3: idle 14 days, checked Monday, report only (no comments, since a
        # first run could comment on dozens of tasks).
        kong-p3-idle = {
          file = ../../modules/server/automations/queries/kong-p3-idle.filter;
          schedule = "Mon *-*-* 06:00:00";
          limit = 300;
          idleDays = 14;
        };

        # Tasks waiting on someone else with no activity for 5 days: time to
        # chase. Monday, Wednesday and Friday, about half the threshold.
        waiting-stale = {
          file = ../../modules/server/automations/queries/waiting-stale.filter;
          schedule = "Mon,Wed,Fri *-*-* 06:00:00";
          limit = 300;
          idleDays = 5;
          flagRepeatDays = 14;
        };

        # p1 and p2 tasks overdue for over a week, however often they were
        # touched. The idle rule misses these (rescheduled or poked, never done).
        overdue-chronic = {
          file = ../../modules/server/automations/queries/overdue-chronic.filter;
          schedule = "Mon *-*-* 06:00:00";
          limit = 300;
        };

        # Inbox tasks older than 3 days: untriaged capture.
        inbox-stale = {
          file = ../../modules/server/automations/queries/inbox-stale.filter;
          schedule = "Mon,Thu *-*-* 06:00:00";
          limit = 300;
        };
      };
    };

    # Todoist task-level UI Extension receiver (see modules/server/claudoist).
    # Enabled ahead of its prerequisites (Task 14 of the claudoist
    # implementation plan, owner: Dustin, manual, not automatable here) so
    # the module + flake wiring can be reviewed and merged as one unit.
    # Until Task 14 is done, items 2/4/5 below are NOT yet satisfied and
    # both claudoist.service and cloudflared-claudoist.service will
    # crash-loop (loud gopass-runner failures on missing 1Password fields, no
    # secret ever half-resolves) rather than silently running broken:
    #   1. `claude` already logged in on srv (~/.claude/.credentials.json).
    #      -- satisfied: shared with incidentInvestigator, already enabled.
    #   2. 1Password automation vault item `claudoist`:
    #      `hmac-verification-token` (from the Todoist App Management Console
    #      UI Extension) and `cloudflared-token` (the tunnel's "Get tunnel
    #      token" value). -- NOT YET DONE.
    #   3. ~/git/claudoist cloned on srv (repoDir default). -- NOT YET DONE.
    #   4. Todoist App Management Console: a context-menu UI Extension on
    #      Task, data-exchange endpoint https://claudoist.srvrs.co/process.
    #      -- NOT YET DONE.
    #   5. Cloudflare Tunnel (remotely-managed / Config type Remote) routing
    #      claudoist.srvrs.co -> http://localhost:8100 (cfg.port's default).
    #      -- NOT YET DONE.
    claudoist = {
      enable = true;
      tunnel.enable = true;
    };

    # Virtualisation on srv moved back from Incus to libvirt/KVM (matching
    # qbert's direction): Talos VMs need real QEMU block-device semantics and
    # a working qemu-guest-agent channel that Incus VMs don't provide (system
    # extensions, in-place upgrades, and the agent itself all broke under
    # Incus). darkstar attaches to br0 (see configuration.nix), an existing
    # Linux bridge replacing the former enp3s0 setup. No NAT-network options
    # needed here either way.
    kvm = {
      enable = true;
      # Disable idle vCPU halt-polling on this hypervisor. The 200us kernel
      # default makes idle vCPUs busy-poll before scheduling out; with 14
      # vCPUs overcommitted on 8 cores across 5 always-on Talos guests, that
      # polling burns host CPU and heat the guests never account as work. 0
      # turns it off; fall back to 50000 (50us) if guest wakeup latency
      # regresses. Applies on the next reboot (kvm stays pinned while VMs
      # run); write /sys/module/kvm/parameters/halt_poll_ns for a live change.
      haltPollNs = 0;
    };

    postgres = {
      enable = true;
      # Allow connections from the LAN so k8s nodes on 192.168.168.0/23 can
      # reach PostgreSQL. Individual databases and roles are added here as
      # cluster services are deployed; localhost is always trusted for local
      # admin use.
      allowedCIDRs = [ "192.168.168.0/23" ];
    };

    # srv hosts the darkstar cluster but was not itself in Grafana: the only
    # node-exporters running were the ones inside the guests, so the hypervisor
    # underneath them reported nothing. Alloy scrapes this from the cluster over
    # br0, which carries both 192.168.168.1 and 192.168.169.200 out of the same
    # /23, so the k8s subnet is the source range.
    nodeExporter = {
      enable = true;
      openFirewallFrom = [ "192.168.168.0/23" ];
    };

    nfs = {
      enable = true;
      exports = {
        spitfire = {
          path = "/exports/spitfire";
          bindMount = "/srv/nfs/spitfire";
          clients = [ "192.168.168.0/23" ];
          # root_squash (default): root on k8s nodes maps to nobody; pods
          # running as non-root UIDs pass through unmapped, so each workload
          # owns its files with its actual UID rather than a shared anonuid.
          squash = "root_squash";
          uid = 1000;
          gid = 100;
        };
        darkstar = {
          path = "/exports/darkstar";
          bindMount = "/srv/nfs/darkstar";
          clients = [ "192.168.168.0/23" ];
          # CSI driver runs as root and creates subdirs under the export root.
          # no_root_squash passes root through so provisioning works.
          squash = "no_root_squash";
          uid = 1000;
          gid = 100;
        };
        # jellyfin-media (path /exports/jellyfin-media, bindMount
        # /home/dustin/data-disk/media) removed 2026-07-31: stale since issue
        # #180 retired NFS from darkstar (zero active NFS clients verified on
        # :2049) and it kept srv mounting /dev/sda1 read-write at the same
        # time the disk is raw-passthrough-mounted read-write inside the
        # darkstar-wk01 Talos guest. That dual mount corrupted a directory
        # btree on it (EXT4-fs error, inode 84279965). The disk is guest-owned
        # only now.
      };
      additionalPaths = [
        {
          path = "/srv/nfs/restores";
          mode = "0755";
          uid = 1000;
          gid = 100;
        }
      ];
    };

    # Read-only Claude Code investigator for darkstar Grafana alerts (the srv
    # side of homelab's incident-investigator/). Enabled now that the
    # operator-owned prerequisites below are met. The module renders no secrets
    # into the store, so eval always succeeds; a missing prerequisite would show
    # as a failing unit, not an eval error.
    #
    # Prerequisites (see homelab incident-investigator/README.md):
    #   1. Clone homelab on srv at ~/git/homelab (repoDir default).
    #   2. Read-only darkstar kubeconfig at ~/.kube/darkstar-ro (a view-bound
    #      ServiceAccount, not admin).
    #   3. 1Password automation vault, item `incident-investigator`, two fields:
    #      `shared-secret` (a random bearer token you invent, e.g.
    #      `openssl rand -hex 32` -- Grafana sends it, receiver.py checks it) and
    #      `cloudflared-token` (the tunnel's "Get tunnel token" value).
    #      Pushover-api already exists.
    #   4. The cloudflared tunnel (remediator.srvrs.co -> http://localhost:8099,
    #      remotely-managed / Config type Remote, behind Cloudflare Access) is
    #      already created; the token from step 3 drives it. Turn on
    #      `incidentInvestigator.tunnel.enable = true` below to run it.
    #   5. Grafana side (a homelab PR): a GrafanaContactPoint (type webhook) to
    #      https://remediator.srvrs.co with the shared secret as the bearer
    #      token, plus a notification-policy route selecting alerts to auto-
    #      investigate. Same pattern as pushover-dustin.
    incidentInvestigator = {
      enable = true;
      tunnel.enable = true;
      # Serve incident bundles on the tailnet so the RCA Pushover ping links to a
      # phone-readable rca.html (https://srv.goat-cloud.ts.net/incidents/...)
      # instead of an unreadable filesystem path. Tailnet-only, never public.
      publish.enable = true;
    };

    # server.nanoclaw: see the NanoClaw note below, above warnings.
    nanoclaw = lib.mkIf nanoclawReady {
      enable = true;
      claudeTokenFile = nanoclawSecretPath "claude-token";
      onecli.dbPasswordFile = nanoclawSecretPath "onecli-db-password";

      # Personal Slack workspace, Socket Mode (no public URL on srv).
      slack = lib.mkIf nanoclawSlackReady {
        enable = true;
        botTokenFile = nanoclawSecretPath "slack-bot-token";
        appTokenFile = nanoclawSecretPath "slack-app-token";
      };
    };
  };

  # NanoClaw personal assistant (modules/server/nanoclaw): host process + one
  # Docker container per agent session, credentials held by the OneCLI Agent
  # Vault so agent containers only ever see a placeholder. Authenticates with
  # the Claude subscription (setup-token), never an API key. Operator guide:
  # extras/docs/nanoclaw/README.md.
  #
  # Secrets use the repo's one pattern (1Password -> render-secrets ->
  # installValue). Each lands at /run/nanoclaw-secrets/<name> (root, 0400) at
  # activation; the module reads them only through systemd LoadCredential, so
  # no value is ever evaluated by Nix. A rotated value changes no store path,
  # so after `just render-secrets` restart the units by hand (README, "Rotate
  # a secret").
  system.activationScripts.nanoclawSecrets = lib.stringAfter [ "etc" ] (
    lib.concatStrings (
      lib.mapAttrsToList installNanoclawSecret (
        lib.optionalAttrs nanoclawReady nanoclawSecrets
        // lib.optionalAttrs nanoclawSlackReady nanoclawSlackSecrets
      )
    )
  );

  warnings =
    lib.optional (!nanoclawReady) ''
      server.nanoclaw is configured on srv but DISABLED: add the nanoclaw keys
      (claudeToken, onecliDbPassword) to secrets.json.tpl, create the 1Password
      items, and run `just render-secrets` (extras/docs/nanoclaw/README.md,
      "Provision the secrets").
    ''
    ++ lib.optional (nanoclawReady && !nanoclawSlackReady) ''
      server.nanoclaw is running terminal-only: add the slackBotToken and
      slackAppToken keys to secrets.json to turn on Slack
      (extras/docs/nanoclaw/README.md, "Slack").
    '';

  apps.cli.restic = {
    enable = true;
    backup = {
      enable = true;
      secretsProfile = "srv";
      # The ad-hoc ~/docker stack (caddy status page, uptime-kuma) was
      # deprecated and removed once forgejo/jellyfin moved to the k8s cluster,
      # so /srv/nfs is the only remaining backup target on srv.
      backupPaths = [
        "/srv/nfs"
      ]
      # NanoClaw state (agent groups and memory, session DBs, Slack wiring)
      # plus nanoclaw-backup's consistent vault/central-DB dumps (02:45, ahead
      # of this 03:00 run). The dumps can decrypt the Claude token; restic
      # encrypts the repo, so they stay protected at rest.
      ++ lib.optionals nanoclawReady [
        config.server.nanoclaw.dataDir
        config.server.nanoclaw.backup.dir
      ];
      restorePath = "/srv/nfs/restores";
    };
  };

  # GitHub access token for nix. srv deliberately does NOT import
  # modules/system/nix (that module is tuned for interactive workstations:
  # desktop-responsive max-jobs/cores and the hyprland cachix substituter).
  # All srv needs from it is the token so `nix flake update` (`just qu`) can
  # resolve the PRIVATE bashfulrobot/upsight flake input via the GitHub API
  # (an unauthenticated resolve 404s). Gated on the secret exactly as the
  # system/nix module is. The token is materialised at system activation into a
  # root-only 0600 file and pulled in via nix.conf `!include` (read by the nix
  # daemon at runtime), so it never enters the world-readable /etc/nix/nix.conf
  # or the store (issue #265). `!include` no-ops when the file is absent.
  # The file this includes is written by system.activationScripts.nixAccessToken
  # in the system block above.
  nix.extraOptions = ''
    !include /run/nixos-secrets/nix-access-tokens.conf
  '';

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}
