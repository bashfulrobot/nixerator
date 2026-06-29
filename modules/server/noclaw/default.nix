{
  config,
  lib,
  pkgs,
  globals,
  ...
}:
# noclaw -- always-on Claude Code Remote Control endpoint, isolated in a
# declarative systemd-nspawn container.
#
# Design (see noclaw repo docs/superpowers/specs/2026-06-27-... for the full
# rationale and the spike that validated RC-under-nspawn):
#   * The endpoint runs INSIDE a NixOS container, not on the host. The repo is
#     bind-mounted READ-ONLY, so the runtime physically cannot modify its own
#     programs or guardrail; only /data is writable. No host home, no secrets.
#   * Authoring happens on the HOST (writable repo) gated by the out-of-band
#     NOCLAW_EDIT flag; the container never has it.
#   * RC needs three cred bits (validated 2026-06-27): ~/.claude/.credentials.json
#     (token), ~/.claude.json (account/org), and a seeded workspace-trust flag
#     for the working dir. We bind-mount the first two READ-ONLY and work on
#     COPIES in a writable container HOME -- the host's live creds are never
#     written by the container.
#   * Egress is locked down by default (egress.lockdown) via a DNS-driven
#     firewall allowlist: a host dnsmasq resolves ONLY egress.allowedHosts and
#     adds their IPs to an ipset, and the FORWARD chain lets the container reach
#     ONLY those IPs (direct TLS, no proxy -- a forward proxy broke RC). Every
#     other new connection from the subnet is dropped. Set egress.lockdown =
#     false for an open POSTROUTING masquerade out the WAN iface (qbert pins the
#     singleton networking.nat.externalInterface to enp34s0).
#   * Recycle timer lives inside the container; autoStart + reboot survival come
#     from the declarative container itself (no user-linger needed).
let
  cfg = config.server.noclaw;

  homeDir = globals.user.homeDirectory;

  claudePkg = pkgs.llm-agents.claude-code;

  # nanoclaw keeps credentials out of the agent entirely by injecting them at a
  # proxy, so the token is never in the container's env, files, or /proc. We have
  # no vault gateway, but we can stop the OP service-account token from living in
  # the long-lived `claude` process env (and thus its /proc/<pid>/environ, which
  # a sibling bin/ program running as the same user could read). This `op` shim
  # loads the token from the bind-mounted file ONLY for the duration of each `op`
  # invocation, so the value is present solely in op's own short-lived env.
  opWrapped = pkgs.writeShellScriptBin "op" ''
    set -euo pipefail
    if [ -r /run/noclaw-op.env ]; then
      set -a
      . /run/noclaw-op.env
      set +a
    fi
    exec ${pkgs._1password-cli}/bin/op "$@"
  '';

  subnet = "10.231.136.0/24";
  hostAddr = "10.231.136.1";
  localAddr = "10.231.136.2";

  # OP service-account token source. Either an operator-provided file
  # (opTokenFile), or rendered at runtime from the nixos-secrets cached JSON
  # (renderOpTokenFromNixosSecrets) into renderedOpEnv. The rendered path reads
  # the already-on-disk cached secrets file at boot -- no 1Password call -- and
  # the value never enters Nix eval or the store.
  secretsJsonPath = "${homeDir}/.config/nixos-secrets/secrets.json";
  renderedOpEnv = "/run/noclaw-op.env";
  # Pinned uid/gid for the in-container `noclaw` user. No user namespacing is in
  # effect (privateUsers off), so a container uid equals the host uid of the same
  # number. Pinning to a value that is free on the host lets the host-side token
  # oneshot grant read by group (root:noclaw-gid, 0640) while the file stays
  # root-only on the host. The user was auto-allocated to 999 before, and an
  # unprivileged process at 999 cannot read the root-owned 0600 token file, so the
  # `op` shim silently got no token. See noclaw-op-token and opWrapped.
  noclawUid = 968;
  noclawGid = 968;
  effectiveOpTokenFile = if cfg.renderOpTokenFromNixosSecrets then renderedOpEnv else cfg.opTokenFile;
  opTokenEnabled = effectiveOpTokenFile != null;

  # Egress-lockdown helpers (used only when cfg.egress.lockdown). The container
  # makes DIRECT TLS connections; a host dnsmasq resolves ONLY the allowlisted
  # domains and adds each resolved A record to the `ipsetName` ipset, and the
  # FORWARD allowlist permits the container to reach only IPs in that set. This
  # is the "DNS-driven firewall allowlist" approach -- no forward proxy, so it
  # works with Claude Code's remote-control registration (which a non-TLS-
  # terminating proxy like tinyproxy could not carry).
  ipsetName = "noclaw_allow";
  egressUpstream = "1.1.1.1";
  # Per-domain dnsmasq directives. `server=/dom/up` gives ONLY allowlisted
  # domains an upstream (unlisted ones don't resolve); `ipset=/dom/set` adds
  # their resolved IPs to the allow set.
  dnsmasqServers = map (d: "/${d}/${egressUpstream}") cfg.egress.allowedHosts;
  dnsmasqIpsets = map (d: "/${d}/${ipsetName}") cfg.egress.allowedHosts;

  # Tools available inside the container to the harness and to bin/ programs.
  # bin/ programs may use these host-level tools internally; the gate hook still
  # confines the agent to clean ./bin/* invocations.
  containerTools = [
    claudePkg
    pkgs.git
    pkgs.coreutils
    pkgs.bash
    pkgs.gnugrep
    pkgs.gnused
    pkgs.findutils
    pkgs.jq
    pkgs.curl
    pkgs.nettools
    pkgs.util-linux
    # Token-scoping `op` shim shadows the real CLI on PATH (see opWrapped). The
    # plain pkgs._1password-cli is intentionally NOT on PATH so every `op` call
    # goes through the shim.
    opWrapped
    pkgs.cacert
  ];

  # Runs as root (ExecStartPre with "+"): the host creds are mode 0600 owned by
  # uid 1000, unreadable by the container's unprivileged noclaw user. Root stages
  # COPIES into the noclaw-owned HOME and chowns them; the host's live creds are
  # never written by the container.
  stageScript = pkgs.writeShellScript "noclaw-rc-stage" ''
    set -euo pipefail
    install -d -m 0700 -o noclaw -g noclaw /var/lib/noclaw/.claude
    cp -f /creds-credentials.json /var/lib/noclaw/.claude/.credentials.json
    cp -f /creds-account.json /var/lib/noclaw/.claude.json
    # Seed workspace trust for the read-only repo working dir.
    tmp="$(mktemp /var/lib/noclaw/.claude.json.XXXXXX)"
    ${pkgs.jq}/bin/jq '.projects["/repo"].hasTrustDialogAccepted = true' \
      /var/lib/noclaw/.claude.json > "$tmp" && mv "$tmp" /var/lib/noclaw/.claude.json
    chown -R noclaw:noclaw /var/lib/noclaw
    chmod 0600 /var/lib/noclaw/.claude/.credentials.json /var/lib/noclaw/.claude.json
    # /data is a root-owned bind-mounted scratch dir (host tmpfiles makes it
    # root:root); hand it to the unprivileged service user so bin/ tasks can
    # actually write output there. Re-applied each start (runs as root via "+").
    chown noclaw:noclaw /data 2>/dev/null || true
    chmod 0750 /data 2>/dev/null || true
  '';

  runScript = pkgs.writeShellScript "noclaw-rc-start" ''
    set -euo pipefail
    export HOME=/var/lib/noclaw
    cd /repo
    exec ${claudePkg}/bin/claude remote-control --name noclaw --spawn session
  '';
in
{
  options.server.noclaw = {
    enable = lib.mkEnableOption "always-on contained Claude Code Remote Control endpoint (noclaw)";

    wanInterface = lib.mkOption {
      type = lib.types.str;
      default = "wlo1";
      example = "enp34s0";
      description = "Host WAN interface the container's egress is masqueraded out of.";
    };

    opTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/noclaw-op-token.env";
      description = ''
        Host path to a rendered file containing `OP_SERVICE_ACCOUNT_TOKEN=...`
        for secret-using bin/ tasks (consumed via `op run`/`op inject`). Point
        this at a least-privilege 1Password service-account token rendered by the
        nixos-secrets pipeline. The file is bind-mounted read-only at
        /run/noclaw-op.env and read ONLY by the `op` shim (see opWrapped), which
        sources it for the lifetime of each `op` call. The token is never placed
        in the long-lived `claude` service environment, so it does not sit in
        that process's /proc/<pid>/environ for the whole session. When null
        (default), no 1Password token is available inside the container.
      '';
    };

    renderOpTokenFromNixosSecrets = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Render the container's `OP_SERVICE_ACCOUNT_TOKEN` from this repo's
        nixos-secrets cached file (`~/.config/nixos-secrets/secrets.json`, key
        `.noclaw.opToken`) into ${renderedOpEnv} via a root oneshot ordered
        before the container, instead of pointing `opTokenFile` at a file
        yourself. The token is read from the already-on-disk cached file at boot
        (no 1Password call), written with mode 0600, and never enters Nix eval
        or the store. Provision the value by adding a least-privilege 1Password
        service-account token to the `nixerator` vault as item `noclaw-op-token`
        and running `just render-secrets`. Mutually exclusive with `opTokenFile`.
      '';
    };

    recycle = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Periodically restart the in-container session to flush context.";
      };
      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 04:00:00";
        example = "Mon *-*-* 04:00:00";
        description = "systemd OnCalendar expression for the periodic context-flush restart.";
      };
    };

    egress = {
      lockdown = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Fail-closed egress allowlist. A host dnsmasq resolves ONLY the domains
          in `egress.allowedHosts` and adds their IPs to an ipset; the container
          may open new connections only to IPs in that set, and its sole resolver
          is that dnsmasq. Everything else from the container subnet is dropped.
          Unlike the old tinyproxy approach this uses DIRECT TLS connections, so
          it is compatible with Claude Code's remote-control registration. When
          false, egress is an open masquerade out `wanInterface` (pre-hardening).
          NOTE: the allowlist must cover every host the session needs at startup
          (the Anthropic API and its feature-flag/telemetry hosts) or remote
          control will not connect -- verify after the first rebuild with it on.
        '';
      };
      allowedHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "anthropic.com"
          "claude.ai"
          "featuregates.org"
          "featureassets.org"
          "statsigapi.net"
          "1password.com"
          "todoist.com"
        ];
        example = [ "api.salesforce.com" ];
        description = ''
          Domain suffixes the egress resolver permits when `egress.lockdown` is
          on (dnsmasq matches a domain and all its subdomains). Defaults cover
          the Anthropic API and Remote Control transport, the statsig
          feature-flag hosts the session needs to start, 1Password (for `op`),
          and the bundled Todoist task. Add a suffix here for every additional
          host a bin/ task must reach.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Container egress. Both modes masquerade the subnet out the WAN iface;
    # lockdown additionally restricts WHICH destinations forward:
    #   * lockdown (default): only IPs the host dnsmasq resolved for an
    #     allowlisted domain are forwarded; every other new connection from the
    #     subnet is dropped (fail-closed). The container's sole resolver is the
    #     host dnsmasq, so it cannot reach a name that isn't on the allowlist.
    #   * open: no destination restriction (pre-hardening).
    # qbert pins the singleton networking.nat.externalInterface to enp34s0, so we
    # add the veth to internalInterfaces and masquerade the subnet out wanInterface
    # ourselves rather than redefining externalInterface.
    networking = {
      nat.internalInterfaces = [ "ve-noclaw" ];

      firewall = {
        extraCommands = lib.mkAfter (
          ''
            iptables -t nat -C POSTROUTING -s ${subnet} -o ${cfg.wanInterface} -j MASQUERADE 2>/dev/null \
              || iptables -t nat -A POSTROUTING -s ${subnet} -o ${cfg.wanInterface} -j MASQUERADE
          ''
          + lib.optionalString cfg.egress.lockdown ''
            # Fail-closed egress allowlist. The ipset is populated by the host
            # dnsmasq (below) as it resolves allowlisted domains. New connections
            # from the container are accepted only to IPs in the set; established
            # return traffic is accepted; everything else from the subnet drops.
            # DNS (container -> host dnsmasq) is INPUT, opened by the ve-noclaw
            # interface rule below, so it is unaffected by these FORWARD rules.
            ${pkgs.ipset}/bin/ipset create -exist ${ipsetName} hash:ip family inet timeout 3600
            iptables -C FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null \
              || iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
            iptables -C FORWARD -s ${subnet} -m set --match-set ${ipsetName} dst -j ACCEPT 2>/dev/null \
              || iptables -A FORWARD -s ${subnet} -m set --match-set ${ipsetName} dst -j ACCEPT
            iptables -C FORWARD -s ${subnet} -j DROP 2>/dev/null \
              || iptables -A FORWARD -s ${subnet} -j DROP
            # The container is v4-only (dnsmasq filters AAAA, sole resolver is v4);
            # drop any IPv6 it might attempt as belt-and-suspenders.
            ip6tables -C FORWARD -i ve-noclaw -j DROP 2>/dev/null \
              || ip6tables -A FORWARD -i ve-noclaw -j DROP
          ''
        );

        extraStopCommands = lib.mkIf cfg.egress.lockdown (
          lib.mkAfter ''
            iptables -D FORWARD -s ${subnet} -m set --match-set ${ipsetName} dst -j ACCEPT 2>/dev/null || true
            iptables -D FORWARD -s ${subnet} -j DROP 2>/dev/null || true
            ip6tables -D FORWARD -i ve-noclaw -j DROP 2>/dev/null || true
          ''
        );

        # DNS only: container -> host dnsmasq (10.231.136.1:53) is INPUT on the veth.
        interfaces."ve-noclaw" = lib.mkIf cfg.egress.lockdown {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };
      };
    };

    # Host-side allowlisting resolver (lockdown only). Resolves ONLY the
    # allowlisted domains and adds each resolved A record to the ${ipsetName}
    # ipset, which the FORWARD allowlist permits. Unlisted domains have no
    # upstream server, so they don't resolve and never enter the set. bind-dynamic
    # copes with the veth /32 appearing after the daemon starts (no nonlocal-bind
    # hack needed). filter-AAAA keeps the container on v4 only.
    services.dnsmasq = lib.mkIf cfg.egress.lockdown {
      enable = true;
      # CRITICAL: this resolver is allowlist-only (it REFUSES anything not in
      # egress.allowedHosts). resolveLocalQueries defaults true, which would make
      # it the HOST's resolver and listen on 127.0.0.1 -- breaking all host DNS
      # (cache.nixos.org etc. would be refused). Keep it false so it serves only
      # the container via ve-noclaw and never touches the host's resolv.conf.
      resolveLocalQueries = false;
      settings = {
        interface = "ve-noclaw";
        bind-dynamic = true;
        no-resolv = true;
        no-hosts = true;
        filter-AAAA = true;
        server = dnsmasqServers;
        ipset = dnsmasqIpsets;
        cache-size = 1000;
      };
    };
    systemd.services.dnsmasq = lib.mkIf cfg.egress.lockdown {
      # Order after the firewall so the ipset exists before dnsmasq populates it,
      # and after the container so the veth (and its address) is up to bind to.
      after = [
        "firewall.service"
        "container@noclaw.service"
      ];
      # Restarting the container recreates ve-noclaw with a fresh /32 host
      # address. bind-dynamic does NOT reliably rebind that IPv4 on its own (it
      # re-grabs only the veth's IPv6 link-local), so the container's resolver
      # silently goes to "connection refused" and all egress -- 1Password auth,
      # Todoist -- fails. partOf propagates the container's restart to dnsmasq;
      # combined with the `after` ordering above, dnsmasq comes back up after the
      # new veth exists and rebinds 10.231.136.1:53.
      partOf = [ "container@noclaw.service" ];
    };

    # Writable scratch volume for the container's runtime output.
    systemd.tmpfiles.rules = [ "d /var/lib/noclaw-data 0750 root root -" ];

    assertions = [
      {
        assertion = !(cfg.renderOpTokenFromNixosSecrets && cfg.opTokenFile != null);
        message = "server.noclaw: set either opTokenFile OR renderOpTokenFromNixosSecrets, not both.";
      }
    ];

    # Render the OP service-account token env file from the nixos-secrets cached
    # JSON before the container starts. Runs as root (default), reads the 0600
    # cached file off disk (no 1Password call), and writes ONLY
    # OP_SERVICE_ACCOUNT_TOKEN=<value> via a command substitution -- the value
    # is never printed or logged. If the key is absent (operator hasn't
    # provisioned noclaw-op-token yet) an EMPTY file is written so the
    # container's read-only bind mount still succeeds; `op` then fails auth
    # cleanly, which is the documented "token not wired yet" state.
    systemd.services.noclaw-op-token = lib.mkIf cfg.renderOpTokenFromNixosSecrets {
      description = "Render noclaw OP service-account token env file from nixos-secrets";
      before = [ "container@noclaw.service" ];
      requiredBy = [ "container@noclaw.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };
      script = ''
        set -euo pipefail
        umask 077
        install -m 0600 /dev/null ${renderedOpEnv}
        if [ -r ${secretsJsonPath} ]; then
          tok="$(${pkgs.jq}/bin/jq -r '.noclaw.opToken // empty' ${secretsJsonPath})"
          if [ -n "$tok" ]; then
            printf 'OP_SERVICE_ACCOUNT_TOKEN=%s\n' "$tok" > ${renderedOpEnv}
          fi
        fi
        # root owns; the container `noclaw` group (gid ${toString noclawGid}) gets
        # read. No host group has this gid, so the file stays root-only on the
        # host while the in-container shim (running as noclaw) can source it.
        chown 0:${toString noclawGid} ${renderedOpEnv}
        chmod 0640 ${renderedOpEnv}
      '';
    };

    containers.noclaw = {
      autoStart = true;
      # Do NOT bounce the container on a host `nixos-rebuild switch`. By default
      # (restartIfChanged = true) any rebuild that changes the container's
      # closure restarts container@noclaw -> restarts the RC service -> mints a
      # NEW remote-control session, which leaves another dead "noclaw" in the
      # phone's Code list (remote-control cannot reuse a session id across a
      # restart; see anthropics/claude-code#29748). false => the running session
      # survives every host rebuild; container/config changes (new claude
      # version, edited scripts) apply on a DELIBERATE `systemctl restart
      # container@noclaw` or a reboot, which is the only time a fresh entry
      # appears. Trade-off: after editing this module you must restart the
      # container by hand for it to take effect.
      restartIfChanged = false;
      privateNetwork = true;
      hostAddress = hostAddr;
      localAddress = localAddr;

      # Container HOME on tmpfs: the staged credential COPIES (.credentials.json,
      # .claude.json) live here and are wiped on every stop/restart instead of
      # persisting in StateDirectory on disk -- nanoclaw's ephemeral-container
      # idea applied to just the secret-bearing dir. StateDirectory=noclaw still
      # owns/permissions it; the recycle timer re-stages on each restart.
      tmpfs = [ "/var/lib/noclaw:mode=0700" ];

      bindMounts = {
        "/repo" = {
          hostPath = "${homeDir}/git/noclaw";
          isReadOnly = true;
        };
        "/data" = {
          hostPath = "/var/lib/noclaw-data";
          isReadOnly = false;
        };
        # Mount ONLY the single credential file the stage step copies -- not all
        # of ~/.claude, which also holds transcripts (projects/), history.jsonl,
        # MCP config, plugins, and sessions. Mirrors nanoclaw's "mount the
        # minimum, never a whole dotfile dir".
        "/creds-credentials.json" = {
          hostPath = "${homeDir}/.claude/.credentials.json";
          isReadOnly = true;
        };
        "/creds-account.json" = {
          hostPath = "${homeDir}/.claude.json";
          isReadOnly = true;
        };
      }
      // lib.optionalAttrs opTokenEnabled {
        "/run/noclaw-op.env" = {
          hostPath = toString effectiveOpTokenFile;
          isReadOnly = true;
        };
      };

      config =
        { lib, ... }:
        lib.mkMerge [
          {
            system.stateVersion = "25.11";
            networking.firewall.enable = false;
            # In lockdown the container's ONLY resolver is the host dnsmasq, which
            # resolves just the allowlisted domains and populates the egress
            # ipset; pointing anywhere else would let it resolve names the
            # firewall then drops. Open mode uses public resolvers.
            networking.nameservers =
              if cfg.egress.lockdown then
                [ hostAddr ]
              else
                [
                  "1.1.1.1"
                  "9.9.9.9"
                ];
            # nspawn otherwise feeds the container the HOST's /etc/resolv.conf
            # (its 127.0.0.1 stub + Tailscale search domain), which has no
            # resolver inside the container's netns -- so networking.nameservers
            # above is ignored and all DNS fails. Force the container to write
            # its own resolv.conf from nameservers, and keep resolved out of it.
            networking.useHostResolvConf = lib.mkForce false;
            services.resolved.enable = false;
            environment.systemPackages = containerTools;

            users.users.noclaw = {
              isSystemUser = true;
              uid = noclawUid;
              group = "noclaw";
              home = "/var/lib/noclaw";
              # script(1) execs the account's login shell; a system user defaults
              # to nologin ("account is currently not available"), so give it bash.
              shell = pkgs.bashInteractive;
            };
            users.groups.noclaw = {
              gid = noclawGid;
            };

            systemd.services.noclaw = {
              description = "noclaw Remote Control endpoint (contained)";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];
              serviceConfig = {
                Type = "simple";
                User = "noclaw";
                Group = "noclaw";
                StateDirectory = "noclaw";
                # The OP service-account token is deliberately NOT loaded into
                # this (long-lived) service env. When opTokenFile is set the token
                # file is bind-mounted at /run/noclaw-op.env and read only by the
                # `op` shim, for the lifetime of each op call. See opWrapped.
                ExecStartPre = "+${stageScript}";
                ExecStart = "${pkgs.util-linux}/bin/script -q -f -c ${runScript} /dev/null";
                Restart = "always";
                RestartSec = "15";
                Environment = [
                  "PATH=${lib.makeBinPath containerTools}"
                  "HOME=/var/lib/noclaw"
                  "SHELL=${pkgs.bashInteractive}/bin/bash"
                  # The endpoint is read-only; never let it try to self-update.
                  # NOTE: we deliberately do NOT set DISABLE_TELEMETRY,
                  # DISABLE_ERROR_REPORTING, or
                  # CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC -- each gates the
                  # feature-flag (statsig) evaluation that `remote-control`
                  # requires, so the session would refuse to start. The egress
                  # allowlist is the real wall: telemetry can't leave unless its
                  # host is in egress.allowedHosts. Egress uses DIRECT TLS
                  # connections (DNS-driven firewall allowlist), so no *_PROXY
                  # vars are set -- the old tinyproxy forward-proxy broke RC.
                  "DISABLE_AUTOUPDATER=1"
                ];
                # Defense in depth atop the container boundary. Kept Node-safe
                # (no MemoryDenyWriteExecute / SystemCallFilter that breaks the
                # JIT); the nspawn namespaces are the primary wall.
                NoNewPrivileges = true;
                CapabilityBoundingSet = "";
                AmbientCapabilities = "";
                RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX";
                RestrictNamespaces = true;
                LockPersonality = true;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectControlGroups = true;
                ProtectHostname = true;
                PrivateTmp = true;
                # Hide other users'/host processes from /proc so a bin/ program
                # can't inspect their environ or cmdline. (ProcSubset=pid is NOT
                # set: it hides /proc/cpuinfo etc., which Node reads at startup.)
                ProtectProc = "invisible";
              };
            };
          }
          (lib.mkIf cfg.recycle.enable {
            systemd.services.noclaw-recycle = {
              description = "Flush noclaw context by restarting the session";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${pkgs.systemd}/bin/systemctl restart noclaw.service";
              };
            };
            systemd.timers.noclaw-recycle = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = cfg.recycle.onCalendar;
                Persistent = true;
              };
            };
          })
        ];
    };
  };
}
