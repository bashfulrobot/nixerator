{
  # Centralized version management for pinned software
  # Check these repositories periodically for updates

  # CLI tools
  cli = {
    meetsum = {
      # Source: https://github.com/bashfulrobot/meetsum/releases
      version = "0.1.2";
      sha256 = "sha256-ew9iAbXPYEG9Dk7e4xg29IKicjA5ASrkLltwPXxEaxc=";
      repo = "https://github.com/bashfulrobot/meetsum";
    };
  };

  # Add future version pins here organized by category:
  # gui = { ... };
  # services = { ... };
}
