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
    devRoot = "${user.homeDirectory}/dev";
    nixRoot = "${user.homeDirectory}/dev/nix";
    nixerator = "${user.homeDirectory}/dev/nix/nixerator";
    hyprflake = "${user.homeDirectory}/dev/nix/hyprflake";
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
    browser = "google-chrome";
  };

  # Remote editing (Zed SSH)
  remoteEdit = {
    user = user.name;
    host = tailscale.qbert;
    projects = [
      "${user.homeDirectory}/dev/nix/nixerator"
      "${user.homeDirectory}/dev/nix/hyprflake"
      "${user.homeDirectory}/dev/go/meetsum"
      "${user.homeDirectory}/dev/go/mcp-tool-proxy"
      "${user.homeDirectory}/dev/kong/lab"
      "${user.homeDirectory}/dev/kong/scratch"
      "${user.homeDirectory}/dev/infra"
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
