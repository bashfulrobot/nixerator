{
  # Centralized version management for pinned software
  # Check these repositories periodically for updates

  # CLI tools
  cli = {
    meetsum = {
      # Source: https://github.com/bashfulrobot/meetsum/releases
      version = "0.4.0";
      sha256 = "sha256-V6sYUAmMB0QlPJcAccJ8bth0BveP/tY/eVSyyjeLTrw=";
      repo = "https://github.com/bashfulrobot/meetsum";
    };
  };

  # Add future version pins here organized by category:
  # gui = { ... };
  # services = { ... };
}
