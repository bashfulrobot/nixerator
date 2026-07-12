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
    editor = "helix"; # Package name in nixpkgs
    shell = "fish";
    browser = "google-chrome-stable";
    terminal = "kitty";
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
    donkeykong = {
      tailscale_ip = "100.117.210.113";
      syncthing_id = "L5XTMUP-FJ4RF5U-GIHYCX6-ZCB3CNA-VY276FE-2INLPNI-Z4M6KQ6-4PPP2AS";
    };
    srv = {
      tailscale_ip = "100.64.187.14";
    };
  };
}
