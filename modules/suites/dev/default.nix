{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.suites.dev;
in
{
  options = {
    suites.dev.enable = lib.mkEnableOption "development suite with AI coding assistants and dev tools";
  };

  config = lib.mkIf cfg.enable {
    # Development tools
    dev = {
      go.enable = true;
      python.enable = true;
    };

    # Development CLI applications
    apps = {
      cli = {
        airship.enable = true;
        amber.enable = true;
        direnv.enable = true;
        # cue: removed
        fresh-editor.enable = true;
        git.enable = true;
        git-cliff.enable = true;
        helix.enable = true;
        lswt.enable = true;
        nix.enable = true;
        nix-init.enable = true;
        nix-search-tv.enable = true;
        pnpm.enable = true;
        shadowenv.enable = true;
        kotlin-lsp.enable = true;
        walkr.enable = true;
        worktree-flow.enable = true;
      };
      gui = {
        upsight.enable = true;
        zed.enable = true;
        zed.nautilusIntegration = true;
      };
    };

    # GPG agent for `pass`. The agent needs a pinentry to prompt for the key
    # passphrase; pinentry-qt reuses the Qt libraries the desktop shell already
    # pulls in. No SSH support: SSH keys come from the 1Password agent.
    programs.gnupg.agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-qt;
    };

    # Development tools
    environment.systemPackages =
      with pkgs;
      [
        filezilla # FTP/SFTP client
        just # Task runner for project commands
        gitleaks # Secret scan (mirrors the cs-webinars CI check)
        pre-commit # Runs the gitleaks hook in service-mesh-webinar
        pass # GPG-backed password store for project secrets
        gnupg # Decryption backend for pass
        gopass # Automation secret store (secauto repo); GPG backend with a passphrase-less key, reads need no prompt
        shfmt # Shell parser the dk auto-gate hook needs (3.14.1 or newer, else it defers every command)
        statix # Nix linter and code quality checker
        fq # jq for binary formats (media, networking, serialization)
        jq # JSON processor
        yq-go # YAML processor
        hugo # Static site generator
        envsubst # Environment variable substitution
        sqlite # SQLite CLI client and library
        sqlite-utils # CLI tool for manipulating SQLite databases
      ]
      ++ [
        pkgs.${globals.preferences.editor} # User's preferred editor
      ];
  };
}
