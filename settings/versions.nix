{
  # Centralized version management for pinned software
  # Check these repositories periodically for updates

  # CLI tools
  cli = {
    meetsum = {
      # Source: https://github.com/bashfulrobot/meetsum/releases
      version = "0.3.0";
      sha256 = "sha256-b2uJtJf8laqGnumsQhCd2qVIkCNUtYn2gfmEUFRnRMk=";
      repo = "https://github.com/bashfulrobot/meetsum";
    };
  };

  # Add future version pins here organized by category:
  # gui = { ... };
  # services = { ... };
}
