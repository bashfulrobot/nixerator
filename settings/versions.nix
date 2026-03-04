{
  # Centralized version management for pinned software
  # Check these repositories periodically for updates

  # CLI tools
  cli = {
    meetsum = {
      # Source: https://github.com/bashfulrobot/meetsum/releases
      version = "0.8.2";
      sha256 = "sha256-j1dBnWUyLJRtN+FPOjSxpWIP8LdI0YG91iJ2bRU+KLs=";
      repo = "https://github.com/bashfulrobot/meetsum";
    };
    cpx = {
      # Source: https://github.com/11happy/cpx/releases
      version = "0.1.3";
      sha256 = "sha256-1qxQgWTxDIRabZRyE5vIo+H0ebzGGB+nyyzO2dujlK4=";
      repo = "https://github.com/11happy/cpx";
    };
    yepanywhere = {
      # Source: https://github.com/kzahel/yepanywhere
      version = "0.4.8";
      sha256 = "sha256-ZOWI7uiU3MdYMLtamWuiSCSdrdXhrVdPIfJkPMHVtYo=";
      npmDepsHash = "sha256-X+uKkERkbQ9cxHZPag6oqcIs2exg4+ncwPwJAEe+gEc=";
      repo = "https://github.com/kzahel/yepanywhere";
    };
    get-shit-done = {
      # Source: https://github.com/gsd-build/get-shit-done
      version = "1.22.4";
      sha256 = "sha256-uW4crLjrx6i02AyoKuQb0BIJ6IIPYkmQygz/RA7Qacc=";
      npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      repo = "https://github.com/gsd-build/get-shit-done";
    };
  };
}
