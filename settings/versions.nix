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
    happy = {
      # Source: https://www.npmjs.com/package/happy-coder
      version = "0.13.0";
      repo = "https://github.com/slopus/happy";
    };
  };

  # Services
  services = {
    stirling-pdf = {
      # Source: https://github.com/Stirling-Tools/Stirling-PDF/releases
      # Using the with-login variant for full feature set (auth, pipeline, etc.)
      version = "2.5.0";
      sha256 = "sha256-GvhmTSraBF+vADa307AdM8neFplbobhFvFjv7LHqDXc=";
      iconSha256 = "sha256-PGdkTQezkoyqePen+fpHeJNHTycI1iHMgjngSaGwD1k=";
      repo = "https://github.com/Stirling-Tools/Stirling-PDF";
    };
  };
}
