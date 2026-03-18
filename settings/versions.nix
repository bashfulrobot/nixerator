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

    cpx = {
      source = "github-release";
      repo = "11happy/cpx";
      version = "0.1.4";
      tagPrefix = "v";
      hash = "sha256-+XqoMGVAxUEY3v/fdlogqe8q2CoyCLK5e6Itp0P/NcE=";
    };

    get-shit-done = {
      source = "npm";
      repo = "gsd-build/get-shit-done";
      npmPkg = "get-shit-done-cc";
      version = "1.25.1";
      hash = "sha256-ELA60LSZYwL99Mr0jHablThLdQwdceNdihh+TaBg4tA=";
      npmDepsHash = "sha256-15I2dWDgJAdG1edG0e9QUvnyp3PxmZ04jTUKqTUXk1U=";
    };

    kubernetes-mcp-server = {
      source = "npm";
      repo = "containers/kubernetes-mcp-server";
      version = "0.0.58";
      hash = "sha256-4gei7GdwUhREKATFBam+lYWotb6qwnJfIpoVoaFmYDQ=";
      npmPkg = "kubernetes-mcp-server-linux-amd64";
    };

    clay = {
      source = "npm";
      repo = "chadbyte/clay";
      npmPkg = "clay-server";
      version = "2.10.0";
      hash = "sha256-2cyvPjcgZPvNKTExA2c0xxNCOe1oGfyOLjj1g8osovI=";
      npmDepsHash = "sha256-7Vr1lVq4GtlqQKZTVtnkZfgGS28wcK/sdOpJsJ1yHho=";
    };

    termly = {
      source = "npm";
      repo = "termly-dev/cli";
      npmPkg = "@termly-dev/cli";
      version = "1.9.0";
      hash = "sha256-lQkgolx5ih2H3qs1l6y30bz2+Spnn6+yUMabioySFHI=";
      npmDepsHash = "sha256-CWnaaJ9BOXQ8La/4UAltritxq1kDRAA6+WoPcUDaF50=";
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

    openspec = {
      source = "npm";
      repo = "Fission-AI/OpenSpec";
      npmPkg = "@fission-ai/openspec";
      version = "1.2.0";
      hash = "sha256-Ks7alGk/HbCw0uo8dQoqQYc36rMNAm0dBmYplFzemLo=";
      npmDepsHash = "sha256-HKLE4ZQ1xZe4GMm2eRQrcyEoShJdteqW++wLmv0Ersw=";
    };

    plannotator = {
      source = "github-release";
      repo = "backnotprop/plannotator";
      version = "0.13.1";
      tagPrefix = "v";
      hash = "sha256-6HAiAP9HHBCUgO7gmqaq81gTt+UAItUnEYxaEY8+IdA=";
      pasteHash = "sha256-9tyfjE4gkdrTuwkgldyRxwdHIcag8wYL3zJ/BJ9mA/g=";
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
