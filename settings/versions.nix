{
  # Centralized version management for pinned software
  # Check these repositories periodically for updates

  # CLI tools
  cli = {
    meetsum = {
      # Source: https://github.com/bashfulrobot/meetsum/releases
      version = "0.8.1";
        sha256 = "sha256-sagits3BzuEvfWDS7YKjmjw6D4ttvRBV0BL7Ut88J2Y=";
      repo = "https://github.com/bashfulrobot/meetsum";
    };
    cpx = {
      # Source: https://github.com/11happy/cpx/releases
      version = "0.1.3";
      sha256 = "sha256-1qxQgWTxDIRabZRyE5vIo+H0ebzGGB+nyyzO2dujlK4=";
      repo = "https://github.com/11happy/cpx";
    };
    happy = {
      # Source: https://www.npmjs.com/package/happy-coder
      version = "0.13.0";
      repo = "https://github.com/slopus/happy";
    };
  };
}
