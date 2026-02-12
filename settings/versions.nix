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

  # GUI applications
  gui = {
    vocalinux = {
      # Source: https://github.com/jatinkrmalik/vocalinux/releases
      version = "0.5.0-beta";
      hash = "sha256-7xT4CykipedsPaguh7COdcCSe8TjOCV5DYv9WVDSGpY=";
      repo = "https://github.com/jatinkrmalik/vocalinux";
    };
  };

  # Add future version pins here organized by category:
  # services = { ... };
}
