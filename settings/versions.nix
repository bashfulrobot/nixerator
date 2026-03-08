{
  # Centralized version management for pinned software
  # Check for updates: just setup::check-updates
  #
  # Schema fields:
  #   source      - fetch strategy: "github-release", "npm", "github-commit", "sourcehut"
  #   repo        - owner/repo (GitHub/SourceHut) or npm package name
  #   version     - semver tag (github-release, npm, sourcehut) or "unstable-YYYY-MM-DD" (github-commit)
  #   rev         - full commit SHA (github-commit only)
  #   tagPrefix   - string prepended to version in the git tag (e.g. "v", "core@", or "")
  #   hash        - SRI hash of the source archive
  #   vendorHash  - Go module vendor hash (Go packages only)
  #   npmDepsHash - hash of npm dependency tree (npm packages only)
  #   npmPkg      - npm registry package name when it differs from the key
  #   platformHashes - per-platform SRI hashes (e.g. insomnia AppImage vs DMG)

  cli = {
    amber = {
      source = "github-release";
      repo = "dalance/amber";
      version = "0.6.1";
      tagPrefix = "v";
      hash = "sha256-/PgoqEnmAawgQCcJ759sRwApWlO2qpAHj/bKYGsn+qk=";
    };

    meetsum = {
      source = "github-release";
      repo = "bashfulrobot/meetsum";
      version = "0.8.3";
      tagPrefix = "v";
      hash = "sha256-bYSk/mYor/dil/Dz4RDkRfpE0412Ue93NR5D+i73ihQ=";
    };

    cpx = {
      source = "github-release";
      repo = "11happy/cpx";
      version = "0.1.3";
      tagPrefix = "v";
      hash = "sha256-1qxQgWTxDIRabZRyE5vIo+H0ebzGGB+nyyzO2dujlK4=";
    };

    yepanywhere = {
      source = "npm";
      repo = "kzahel/yepanywhere";
      npmPkg = "yepanywhere";
      version = "0.4.8";
      hash = "sha256-ZOWI7uiU3MdYMLtamWuiSCSdrdXhrVdPIfJkPMHVtYo=";
      npmDepsHash = "sha256-X+uKkERkbQ9cxHZPag6oqcIs2exg4+ncwPwJAEe+gEc=";
    };

    get-shit-done = {
      source = "npm";
      repo = "gsd-build/get-shit-done";
      npmPkg = "get-shit-done-cc";
      version = "1.22.4";
      hash = "sha256-uW4crLjrx6i02AyoKuQb0BIJ6IIPYkmQygz/RA7Qacc=";
      npmDepsHash = "sha256-15I2dWDgJAdG1edG0e9QUvnyp3PxmZ04jTUKqTUXk1U=";
    };

    superpowers = {
      source = "github-commit";
      repo = "obra/superpowers";
      version = "unstable-2025-03-01";
      rev = "e4a2375cb705ca5800f0833528ce36a3faf9017a";
      hash = "sha256-AeICtdAfWRp0oCgQqd8LdrEWWtKNqUNWdvn0CGL18fA=";
    };

    kubernetes-mcp-server = {
      source = "npm";
      repo = "containers/kubernetes-mcp-server";
      version = "0.0.57";
      hash = "sha256-csF1HhRFqccBcu+jCkRSIhxNJhhO6jMBISL81RMlLBc=";
      npmPkg = "kubernetes-mcp-server-linux-amd64";
    };

    lswt = {
      source = "sourcehut";
      repo = "~leon_plickat/lswt";
      version = "2.0.0";
      tagPrefix = "v";
      hash = "sha256-8jP6I2zsDt57STtuq4F9mcsckrjvaCE5lavqKTjhNT0=";
    };

    lazyrestic = {
      source = "github-commit";
      repo = "craigderington/lazyrestic";
      version = "unstable-2025-12-30";
      rev = "b59e26f06da7b35f587b97cf0804b0e66b78f1e1";
      hash = "sha256-Uezahy0f1/3wnuYQscXgpb0iFXWTvP0I1V5TPcmrV3A=";
      vendorHash = "sha256-MIq04ecsWq2DEbt6myCm4VqQYqjlAmTScDv0OXm9XV4=";
    };
  };

  gui = {
    insomnia = {
      source = "github-release";
      repo = "Kong/insomnia";
      version = "12.3.1";
      tagPrefix = "core@";
      platformHashes = {
        x86_64-linux = "sha256-Bcja3z/QKdJ6NNvrRjSPPUsuqy53JveAiJ8jYrwg2uY=";
        aarch64-darwin = "sha256-eKHZjZ8nVRIC28LJlokWop0xHGYyYcUS6ehzu5I/8CE=";
        x86_64-darwin = "sha256-eKHZjZ8nVRIC28LJlokWop0xHGYyYcUS6ehzu5I/8CE=";
      };
    };

    helium = {
      source = "github-release";
      repo = "imputnet/helium-linux";
      version = "0.9.1.1";
      tagPrefix = "";
      hash = "sha256-0Kw8Ko41Gdz4xLn62riYAny99Hd0s7/75h8bz4LUuCE=";
    };
  };

  fish-plugins = {
    zoxide-fish = {
      source = "github-release";
      repo = "icezyclon/zoxide.fish";
      version = "3.0";
      tagPrefix = "";
      hash = "sha256-OjrX0d8VjDMxiI5JlJPyu/scTs/fS/f5ehVyhAA/KDM=";
    };
  };
}
