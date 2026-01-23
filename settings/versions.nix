{
  # Centralized version management for pinned software
  # Check these repositories periodically for updates

  # CLI tools
  cli = {
    meetsum = {
      # Source: https://github.com/bashfulrobot/meetsum/releases
      version = "0.2.0";
      sha256 = "sha256-DaRZYW+DXdmLN82zj8hysbunW3dA2N49HKyLhe9VvNo=";
      repo = "https://github.com/bashfulrobot/meetsum";
    };
  };

  # Add future version pins here organized by category:
  # gui = { ... };
  # services = { ... };
}
