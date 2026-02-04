{
  # Centralized version management for pinned software
  # Check these repositories periodically for updates

  # CLI tools
  cli = {
    meetsum = {
      # Source: https://github.com/bashfulrobot/meetsum/releases
      version = "0.5.0";
      sha256 = "sha256-Oyqj4DHUOyxxvNVDtDKQSagX48k87o9p9baqLxBiJec=";
      repo = "https://github.com/bashfulrobot/meetsum";
    };
  };

  # Add future version pins here organized by category:
  # gui = { ... };
  # services = { ... };
}
