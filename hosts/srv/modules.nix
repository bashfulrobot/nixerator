{ secrets, ... }:

{
  # Import only modules that srv used in nixcfg, plus the cherry-picked
  # Claude Code + zellij web stack.
  imports = [
    ../../modules/apps/cli/agent-scan
    ../../modules/apps/cli/agentos
    ../../modules/apps/cli/claude-code
    ../../modules/apps/cli/claude-external-skills
    ../../modules/apps/cli/docker
    ../../modules/apps/cli/fish
    ../../modules/apps/cli/gemini-cli
    ../../modules/apps/cli/graymatter
    ../../modules/apps/cli/helix
    ../../modules/apps/cli/paseo
    ../../modules/apps/cli/plannotator
    ../../modules/apps/cli/restic
    ../../modules/apps/cli/skillfish
    ../../modules/apps/cli/starship
    ../../modules/apps/cli/stop-slop
    ../../modules/apps/cli/superpowers
    ../../modules/apps/cli/tailscale
    ../../modules/apps/cli/vscode-server
    ../../modules/apps/cli/zellij
    ../../modules/server/kvm
    ../../modules/server/nfs
    ../../modules/system/caddy
    ../../modules/system/ssh
  ];

  # CLI applications (matching nixcfg srv)
  apps.cli = {
    docker.enable = true;
    fish.enable = true;
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
      # NOTE: keep plugin list in sync with modules/suites/ai/default.nix.
      # Two occurrences = below the rule-of-three threshold; do not
      # extract into shared lib until a third consumer appears.
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
    claude-external-skills.enable = true;
    gemini-cli.enable = true;
    graymatter.enable = true;
    paseo.enable = true;
    plannotator.enable = true;
    skillfish.enable = true;
    stop-slop.enable = true;
    superpowers.enable = true;

    # Zellij with web client behind Caddy tsnet
    zellij = {
      enable = true;
      service.enable = true;
      tsnetNode = "zellij";
    };
  };

  # System modules
  system.ssh.enable = true;

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
