{
  # Centralized version management for pinned software
  # Check these repositories periodically for updates

  # CLI tools
  cli = {
    amber = {
      # Source: https://github.com/dalance/amber/releases
      version = "0.6.1";
      sha256 = "sha256-/PgoqEnmAawgQCcJ759sRwApWlO2qpAHj/bKYGsn+qk=";
      repo = "https://github.com/dalance/amber";
    };
    meetsum = {
      # Source: https://github.com/bashfulrobot/meetsum/releases
      version = "0.8.3";
      sha256 = "sha256-bYSk/mYor/dil/Dz4RDkRfpE0412Ue93NR5D+i73ihQ=";
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
      repo = "https://github.com/gsd-build/get-shit-done";
    };
    superpowers = {
      # Source: https://github.com/obra/superpowers
      rev = "e4a2375cb705ca5800f0833528ce36a3faf9017a";
      hash = "sha256-AeICtdAfWRp0oCgQqd8LdrEWWtKNqUNWdvn0CGL18fA=";
      repo = "https://github.com/obra/superpowers";
    };
  };
}
