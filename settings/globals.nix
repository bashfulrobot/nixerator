rec {
  # Global configuration variables available throughout your flake

  # User configuration
  user = {
    name = "dustin";
    fullName = "Dustin Krysak";
    email = "dustin@bashfulrobot.com";
    homeDirectory = "/home/dustin";
  };

  # Common repository and development paths
  paths = {
    devRoot = "${user.homeDirectory}/git";
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
    terminal = "ghostty";
  };

  # Remote editing (Zed SSH)
  remoteEdit = {
    user = user.name;
    host = tailscale.qbert;
    projects = [
      "${user.homeDirectory}/git/nixerator"
      "${user.homeDirectory}/git/hyprflake"
      "${user.homeDirectory}/git/meetsum"
      "${user.homeDirectory}/git/mcp-tool-proxy"
      "${user.homeDirectory}/git/infra"
    ];
  };

  # Tailscale IPs
  tailscale = {
    qbert = "100.74.137.95";
    donkeykong = "100.117.210.113";
    srv = "100.64.187.14";
  };

  # Git configuration
  git = {
    # SSH public key for commit signing
    gitPubSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICF9sPiX7zVCn+SW7bQpgS+dhUlVJYNktP6PO4mJWUJZ dustin@bashfulrobot.com";
  };
}
