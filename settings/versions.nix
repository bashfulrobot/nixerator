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
    cpx = {
      # Source: https://github.com/11happy/cpx/releases
      version = "0.1.3";
      sha256 = "sha256-1qxQgWTxDIRabZRyE5vIo+H0ebzGGB+nyyzO2dujlK4=";
      repo = "https://github.com/11happy/cpx";
    };
  };

  # Add future version pins here organized by category:
  # services = { ... };
}
