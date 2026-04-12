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
  #   pasteHash   - SRI hash of an auxiliary paste/clipboard asset (e.g. plannotator)
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
      version = "0.9.0";
      tagPrefix = "v";
      hash = "sha256-dbQ4ypYrGr0vyA67fcD+pSHHSVEAKNitdzKOM6hig2U=";
    };

    gws = {
      source = "github-release";
      repo = "googleworkspace/cli";
      version = "0.22.5";
      tagPrefix = "v";
      hash = "sha256-3njs29LxqEzKAGOn7LxEAkD8FLbrzLsX9GRreSqMXB8=";
    };

    salesforce-cli = {
      source = "github-release";
      repo = "salesforcecli/cli";
      version = "2.131.5";
      tagPrefix = "";
      shortRev = "8ade7c8";
      hash = "sha256-Ut4e39jXZLnzb7qNSKHpuTuv8s6gLKWDhSfr90ITJE4=";
    };

    cpx = {
      source = "github-release";
      repo = "11happy/cpx";
      version = "0.1.4";
      tagPrefix = "v";
      hash = "sha256-+XqoMGVAxUEY3v/fdlogqe8q2CoyCLK5e6Itp0P/NcE=";
    };

    kubernetes-mcp-server = {
      source = "npm";
      repo = "containers/kubernetes-mcp-server";
      version = "0.0.60";
      hash = "sha256-mSlM8BKYqe64noSloqqwSmogCznxMvzdSO5Z1nbJtko=";
      npmPkg = "kubernetes-mcp-server-linux-amd64";
    };

    clay = {
      source = "npm";
      repo = "chadbyte/clay";
      npmPkg = "clay-server";
      version = "2.25.0";
      hash = "sha256-TV+OK9ani9te8G+Yot1LBSWRhVcJ+2dTs1ujb2HOxEg=";
      npmDepsHash = "sha256-APUvm7E2q4bQ3xFx1PspXgW5GSstA4AAuQiiGXuNq68=";
    };

    lswt = {
      source = "sourcehut";
      repo = "~leon_plickat/lswt";
      version = "2.0.0";
      tagPrefix = "v";
      hash = "sha256-8jP6I2zsDt57STtuq4F9mcsckrjvaCE5lavqKTjhNT0=";
    };

    sheets = {
      source = "github-release";
      repo = "maaslalani/sheets";
      version = "0.2.0";
      tagPrefix = "v";
      hash = "sha256-sRJ1rqtxc4axAkVavxSR2afdvxCAjJdK2mBWnt+nzW0=";
      vendorHash = "sha256-WWtAt0+W/ewLNuNgrqrgho5emntw3rZL9JTTbNo4GsI=";
    };

    jwtx = {
      source = "github-release";
      repo = "gurleensethi/jwtx";
      version = "0.5.0";
      tagPrefix = "";
      hash = "sha256-DtgZRrF5s0SMEZnMYp5a8zkDptYbB6h0ihuP8PpGgWY=";
      vendorHash = "sha256-/6DyRRvfyShQUSFmpmuSxrd1bhBh6Km8kaMutA4xrH4=";
    };

    reap = {
      source = "npm";
      repo = "c-d-cc/reap";
      npmPkg = "@c-d-cc/reap";
      version = "0.16.4";
      hash = "sha256-ABgVEgvlYrPZh9MzTpNlTZp7jfhsOjFlloU0Rltkkio=";
      npmDepsHash = "sha256-Hdf0YhSTfUUeTnfMKrokdAha8Vw70WMB0BS8OIpArEI=";
    };

    plannotator = {
      source = "github-release";
      repo = "backnotprop/plannotator";
      version = "0.17.1";
      tagPrefix = "v";
      hash = "sha256-UYoImMYyu9BposkwrXLPZiQsse3aHg5Aims2Ekbs59o=";
      pasteHash = "sha256-9tyfjE4gkdrTuwkgldyRxwdHIcag8wYL3zJ/BJ9mA/g=";
    };

    kotlin-lsp = {
      source = "github-release";
      repo = "Kotlin/kotlin-lsp";
      version = "262.2310.0";
      tagPrefix = "kotlin-lsp/v";
      hash = "sha256-wAQkIVj0teHZF93YSOb2onlIT6WKPivOiEa4B9GtFrE=";
    };

    stop-slop = {
      source = "github-commit";
      repo = "hardikpandya/stop-slop";
      version = "unstable-2026-04-04";
      rev = "65d52b35d7243427ac646e83eae5a9b0709aa191";
      hash = "sha256-NcwN37kSKOO+4QIhIEVafFtg15KCufmxTJiX3AGQRh0=";
    };

    gurk = {
      source = "github-release";
      repo = "boxdot/gurk-rs";
      version = "0.9.0";
      tagPrefix = "v";
      hash = "sha256-ZTT1wJvNuYjd1QYjw5lVC2C+MZNu0NBmeEi5eOO+f5c=";
    };

    happy = {
      source = "npm";
      repo = "nichochar/happy-coder";
      npmPkg = "happy-coder";
      version = "0.13.1";
      hash = "sha256-xMMKZLAEN/j8cbIjsaHS67csfbuhnW7ulUPu1tVf+Ao=";
      npmDepsHash = "sha256-+zgPB7lD039NR6U0+MbFshZh12cHdmfMUf+JzEyZDoQ=";
    };

    crawl4ai = {
      source = "github-release";
      repo = "unclecode/crawl4ai";
      version = "0.8.5";
      tagPrefix = "v";
      hash = "sha256-y5Nve8e41+wcTlymL6bXxPCwmN8+8/YvHYLGO3x4M+Q=";
    };

  };

  gui = {
    comics-downloader = {
      source = "github-release";
      repo = "Girbons/comics-downloader";
      version = "0.33.9";
      tagPrefix = "v";
      hash = "sha256-/Y7m7D7l2j42eErkD5+YNw01w/hJ3k3K4JEDKmCPw0w=";
      vendorHash = "sha256-aVDe+SFszKQPXeOdkh9l7iO0yfdIcVQp+rXqkDUY92U=";
    };

    insomnia = {
      source = "github-release";
      repo = "Kong/insomnia";
      version = "12.5.0";
      tagPrefix = "core@";
      platformHashes = {
        x86_64-linux = "sha256-RYNzOX9WRPqPUMhbG/Ab4Ip25imudNGlHX1kPLzuQ+U=";
        aarch64-darwin = ""; # placeholder -- no darwin builds currently used
        x86_64-darwin = ""; # placeholder -- no darwin builds currently used
      };
    };

    helium = {
      source = "github-release";
      repo = "imputnet/helium-linux";
      version = "0.10.8.1";
      tagPrefix = "";
      hash = "sha256-pN/Iw1ANggDOxxFb2CN436qbcrs8/bDcEqjZC80grQs=";
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
