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

    kiyoproctrls = {
      # Source: https://github.com/soyersoyer/kiyoproctrls
      version = "unstable-2022-06-08";
      rev = "1aeb0226ab416b592ee39e0ecc8ccacd2e7e0efc";
      sha256 = "sha256-Y+lrWaWEWmpkSAOWJMquUM/XuiAjZvz3XW94iPSy66U=";
      repo = "https://github.com/soyersoyer/kiyoproctrls";
    };
  };

  # Add future version pins here organized by category:
  # gui = { ... };
  # services = { ... };
}
