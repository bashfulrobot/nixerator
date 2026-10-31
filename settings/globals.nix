rec {
  # Global configuration variables available throughout your flake

  # User configuration
  user = {
    name = "dustin";
    fullName = "Dustin Krysak";
    email = "dustin@bashfulrobot.com";
    homeDirectory = "/home/dustin";

    # Public keys permitted to log in over regular OpenSSH (issue #107: moved
    # off the Tailscale SSH server). Reuses the ed25519 key also used for git
    # commit signing (git.gitPubSigningKey) -- the public half of the
    # ~/.ssh/id_ed25519 pair SSH'd with on the workstations. Add more keys
    # here as needed. VERIFY this matches the private key you actually SSH
    # with before disabling password auth.
    sshAuthorizedKeys = [
      git.gitPubSigningKey
    ];
  };

  # Common repository and development paths
  paths = {
    devRoot = "${user.homeDirectory}/dev";
    notes = "${user.homeDirectory}/Notes";
    nixerator = "${user.homeDirectory}/git/nixerator";
    hyprflake = "${user.homeDirectory}/git/hyprflake";
  };

  # System defaults
  defaults = {
    stateVersion = "25.11";
    timeZone = "America/Vancouver";
    locale = "en_US.UTF-8";
  };

  # Editor and shell preferences
  preferences = {
    editor = "fresh-editor"; # Package name in nixpkgs
    shell = "fish";
    browser = "google-chrome-stable";
    terminal = "kitty";
  };

  # Local AI (Ollama) defaults. Single source for the model that both the
  # server-side pull (apps.cli.ollama.loadModels) and the opencode client
  # default (apps.cli.ollama.defaultOpencodeModel) reference, so the pulled
  # model and the requested model cannot drift out of sync. Qwen3.6 35B-A3B
  # (22 GB, MoE with 3B active) runs 65% on the 16 GB GPU and 35% on CPU. On
  # qbert (2026-10-18) it scored 10/10 on a 10-task tool-call test at 71
  # tokens/s and fixed a failing pytest through opencode, where dense
  # qwen3:14b scored 9/10 at 47 tokens/s. That test replaced the earlier
  # worry that MoE models call tools unreliably under Ollama (Mellum2 did).
  # Fallbacks pulled by hand: gpt-oss:20b (97 tokens/s, fits VRAM) and
  # qwen3:14b.
  ai = {
    localCodeModel = "qwen3.6:35b-a3b";
  };

  # Remote editing (Zed SSH)
  remoteEdit = {
    user = user.name;
    projects = [
      "${user.homeDirectory}/git/nixerator"
      "${user.homeDirectory}/git/hyprflake"
      "${user.homeDirectory}/git/meetsum"
      "${user.homeDirectory}/git/mcp-tool-proxy"
      "${user.homeDirectory}/git/infra"
    ];
  };

  # Git configuration
  git = {
    # SSH public key for commit signing
    gitPubSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICF9sPiX7zVCn+SW7bQpgS+dhUlVJYNktP6PO4mJWUJZ dustin@bashfulrobot.com";
  };

  # Per-host network identity. These are NOT secrets -- they're already
  # published in extras/docs/{termly-remote.md,index.html} and don't grant
  # access on their own (you'd need a tailscale auth key, which IS in 1P).
  # Lives here instead of in the nixerator 1P vault so adding/removing a
  # host doesn't require an op item create/delete.
  hosts = {
    qbert = {
      tailscale_ip = "100.74.137.95";
      syncthing_id = "P4GTYZK-MK4AIO5-6JCS4PG-VUACBUS-DP6XERC-ZQGAJAI-PU5WNPB-XTUVEQ2";
    };
    srv = {
      tailscale_ip = "100.64.187.14";
      syncthing_id = "S7CHB5E-MDKYOC2-MULZHWM-QJ5ZQHH-VFZVYER-ZDFLDON-T5R4JES-HEHVGAE";
    };
    # Mac, managed by the separate ../donkeykong repo (Homebrew + chezmoi, no
    # longer nix-darwin/mixerator). Only relevant here as a Syncthing peer for
    # upsight-data/upsight-config -- see apps/cli/syncthing.
    #
    # Both values are the *rebuilt* Mac's, not the one this entry described
    # before: a reinstall regenerates the Syncthing device identity, and the
    # tailnet handed it a new address. donkeykong's syncthing.sh prints the ID
    # it is actually running, which is where these came from.
    MH36P2YMHX = {
      tailscale_ip = "100.65.120.127";
      syncthing_id = "M23RLFB-QRXLIZW-67Z2H66-XTZ3RC6-JYHXORL-2I5X36Q-3LXJ5CS-AFIAXQ7";
    };
  };
}
