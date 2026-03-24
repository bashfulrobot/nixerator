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
      version = "0.8.3";
      tagPrefix = "v";
      hash = "sha256-bYSk/mYor/dil/Dz4RDkRfpE0412Ue93NR5D+i73ihQ=";
    };

    gws = {
      source = "github-release";
      repo = "googleworkspace/cli";
      version = "0.18.1";
      tagPrefix = "v";
      hash = "sha256-58xElaYWrNL+kzg/xVwFRDlL2ga39tY6NikDBTvLO6Q=";
    };

    salesforce-cli = {
      source = "github-release";
      repo = "salesforcecli/cli";
      version = "2.129.2";
      tagPrefix = "";
      shortRev = "693b340";
      hash = "sha256-Q6dRRGDLX4oofVacd30hkxARdoqwItw0ukLvvyLtAtE=";
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
      version = "0.0.59";
      hash = "sha256-i9x3rZusmPFugDE3xprvIKbB1naTUAVqJbGkWUANaEA=";
      npmPkg = "kubernetes-mcp-server-linux-amd64";
    };

    clay = {
      source = "npm";
      repo = "chadbyte/clay";
      npmPkg = "clay-server";
      version = "2.12.0";
      hash = "sha256-5XZPqZKJQDS4xLCpkc+CBdBCJd7qw8HPKuPDauPNl0k=";
      npmDepsHash = "sha256-7Vr1lVq4GtlqQKZTVtnkZfgGS28wcK/sdOpJsJ1yHho=";
    };

    lswt = {
      source = "sourcehut";
      repo = "~leon_plickat/lswt";
      version = "2.0.0";
      tagPrefix = "v";
      hash = "sha256-8jP6I2zsDt57STtuq4F9mcsckrjvaCE5lavqKTjhNT0=";
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
      version = "0.12.0";
      hash = "sha256-nxJ1dCxNKVD5G9LNC4Jm5t4+ZGoL67cfTWL7s4cwmDI=";
      npmDepsHash = "sha256-3WBC0C6hE/4WKLycaO0fvkuOP+wT4hj44kM7Rj+ld2U=";
    };

    sled = {
      source = "github-commit";
      repo = "layercodedev/sled";
      version = "unstable-2026-01-26";
      rev = "f5a3746627e9de3b1b796e7e4c5a98bcd1de10ad";
      hash = "sha256-U1E46cNHCU1zzD45OOYLlTrxtEFx1TaMxeZyzNH8HJs=";
      pnpmDepsHash = "sha256-92f1jC1G1BjGd5SmcGAB/Jo1BRJ6YBfNvjMCsifDYUs=";
    };

    plannotator = {
      source = "github-release";
      repo = "backnotprop/plannotator";
      version = "0.14.2";
      tagPrefix = "v";
      hash = "sha256-DsGu6zUtquJjqPUzlKp7SdeBIdaV0O9pfFQtZ9NBVB8=";
      pasteHash = "sha256-9tyfjE4gkdrTuwkgldyRxwdHIcag8wYL3zJ/BJ9mA/g=";
    };

    gurk = {
      source = "github-release";
      repo = "boxdot/gurk-rs";
      version = "0.9.0";
      tagPrefix = "v";
      hash = "sha256-ZTT1wJvNuYjd1QYjw5lVC2C+MZNu0NBmeEi5eOO+f5c=";
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
      version = "12.4.0";
      tagPrefix = "core@";
      platformHashes = {
        x86_64-linux = "sha256-QHa+BEGDIYsOxE49bL9bXmeYRKewx1P3FQ5bi3iz92w=";
        aarch64-darwin = ""; # placeholder -- no darwin builds currently used
        x86_64-darwin = ""; # placeholder -- no darwin builds currently used
      };
    };

    helium = {
      source = "github-release";
      repo = "imputnet/helium-linux";
      version = "0.10.5.1";
      tagPrefix = "";
      hash = ""; # placeholder -- populate when apps.gui.helium.enable = true
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
