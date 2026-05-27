{ secrets, globals, ... }:

{
  # Import only modules that srv used in nixcfg, plus the cherry-picked
  # Claude Code + zellij web stack.
  imports = [
    ../../modules/apps/cli/agent-scan
    ../../modules/apps/cli/agentos
    ../../modules/apps/cli/claude-code
    ../../modules/apps/cli/docker
    ../../modules/apps/cli/fish
    ../../modules/apps/cli/gcmt
    ../../modules/apps/cli/gemini-cli
    ../../modules/apps/cli/git
    ../../modules/apps/cli/graymatter
    ../../modules/apps/cli/helix
    ../../modules/apps/cli/plannotator
    ../../modules/apps/cli/restic
    ../../modules/apps/cli/skillfish
    ../../modules/apps/cli/starship
    ../../modules/apps/cli/superpowers
    ../../modules/apps/cli/tailscale
    ../../modules/apps/cli/vscode-server
    ../../modules/apps/cli/work-launcher
    ../../modules/apps/cli/zellij
    ../../modules/archetypes/claudeWorkHost
    ../../modules/server/kvm
    ../../modules/server/netboot-xyz
    ../../modules/server/nfs
    ../../modules/system/caddy
    ../../modules/system/ssh
  ];

  # Adopts the Claude work-host archetype: zellij (no web, no mosh),
  # sshd, work-launcher. Sessions live on srv until killed; attach from
  # anywhere on the tailnet via `work` or `ssh srv zellij attach`.
  archetypes.claudeWorkHost.enable = true;

  # CLI applications (matching nixcfg srv)
  apps.cli = {
    docker.enable = true;
    fish.enable = true;
    git.enable = true;
    helix.enable = true;
    starship.enable = true;
    tailscale.enable = true;
    vscode-server.enable = false;

    # Claude Code stack (cherry-picked from suites/ai for headless srv)
    agent-scan.enable = true;
    agentos.enable = true;
    claude-code = {
      enable = true;
      serverProfile = "minimal";
      # NOTE: keep plugin list in sync with modules/suites/ai/default.nix,
      # EXCEPT "hyperframes@hyperframes" -- workstation-only because it pulls
      # in ffmpeg + node + puppeteer env vars and assumes a Chromium-family
      # browser binary at /run/current-system/sw/bin/${globals.preferences.browser}
      # (provisioned via suites.browsers on workstations). srv is headless and
      # has no browser. Two occurrences = below the rule-of-three threshold;
      # do not extract into shared lib until a third consumer appears.
      plugins = [
        "frontend-design@claude-plugins-official"
        "asana@claude-plugins-official"
        "code-review@claude-plugins-official"
        "context7@claude-plugins-official"
        "github@claude-plugins-official"
        "feature-dev@claude-plugins-official"
        "commit-commands@claude-plugins-official"
        "security-guidance@claude-plugins-official"
        "pr-review-toolkit@claude-plugins-official"
        "atlassian@claude-plugins-official"
        "learning-output-style@claude-plugins-official"
        "slack@claude-plugins-official"
        "gopls-lsp@claude-plugins-official"
        "skill-creator@claude-plugins-official"
        "ralph-loop@claude-plugins-official"
      ];
    };
    gemini-cli.enable = true;
    plannotator.enable = true;
    skillfish.enable = true;
    superpowers.enable = true;
  };

  # System modules
  system.ssh.enable = true;
  # ssh-agent is managed by `keychain` (see hosts/srv/home.nix) so it
  # persists across SSH sessions on this headless box. Do NOT also set
  # `programs.ssh.startAgent` — that would spawn a per-session agent
  # and defeat keychain's single-agent model.

  # Server-specific modules
  server = {
    kvm = {
      enable = true;
      routing = {
        enable = true;
        externalInterface = "enp3s0";
        internalInterfaces = [
          "virbr1"
          "virbr2"
          "virbr3"
          "virbr4"
          "virbr5"
          "virbr6"
          "virbr7"
        ];
        proxyArpInterfaces = [ "ens2" ];
      };
    };

    netbootXyz = {
      enable = true;
      # Bind container ports to specific host IPs. Listener-binding is the
      # primary exposure control on srv because the kvm module's INPUT-
      # accept override neuters firewall scoping. LAN ports bind to enp3s0;
      # admin UI binds LAN + Tailscale.
      lanAddress = "192.168.168.1";
      adminAddresses = [
        "192.168.168.1"
        globals.hosts.srv.tailscale_ip
      ];
    };

    nfs = {
      enable = true;
      exports = {
        spitfire = {
          path = "/exports/spitfire";
          bindMount = "/srv/nfs/spitfire";
          exportConfig = "172.16.166.0/24(rw,sync,no_subtree_check,no_root_squash,all_squash,anonuid=1000,anongid=100)";
          uid = 1000;
          gid = 100;
        };
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

  };

  apps.cli.restic = {
    enable = true;
    backup = {
      enable = true;
      repository = secrets.restic.srv.restic_repository;
      password = secrets.restic.srv.restic_password;
      awsAccessKeyId = secrets.restic.srv.b2_account_id;
      awsSecretAccessKey = secrets.restic.srv.b2_account_key;
      awsRegion = secrets.restic.srv.region;
      backupPaths = [ "/srv/nfs" ];
      restorePath = "/srv/nfs/restores";
      schedule = "*-*-* 03:00:00";
      keepDaily = 7;
      keepWeekly = 4;
      keepMonthly = 12;
      keepYearly = 2;
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}
