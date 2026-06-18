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
    agent-scan = {
      source = "github-release";
      repo = "snyk/agent-scan";
      version = "0.5.1";
      tagPrefix = "v";
      platformHashes = {
        x86_64-linux = "sha256-mRU++DkLpEhuJ4X1vBjyzhWSTGEE7Cx1ccy5ac6NOi0=";
        aarch64-darwin = "sha256-WYAHJkZ5Lh3loWIbpFVuDNKPyfFhTQWHWVjksdgUQ04=";
        x86_64-darwin = "sha256-OoKrOM3b0chpgyL52/+N1lMapeeuD716CIrxMgbcaT8=";
      };
    };

    agentos = {
      source = "github-release";
      repo = "buildermethods/agent-os";
      version = "3.0.0";
      tagPrefix = "v";
      hash = "sha256-NKjR19bHw/fFmkzSxMa5RV9CjYk3SrLjFyyuFE4Cdvs=";
    };

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
      version = "2.134.6";
      tagPrefix = "";
      shortRev = "f556e1e";
      hash = "sha256-OXaMFwpICKlNArUmgABV9X5I/I+ah2ZLJVMCZ7nsFTc=";
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
      version = "0.0.62";
      hash = "sha256-+OH0rg/0v5xrY+bCjK1N3NQHDrWVd8g9REJv5C+RiF0=";
      npmPkg = "kubernetes-mcp-server-linux-amd64";
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

    # NOTE: 262.4739.0 is available but upstream renamed assets
    # (kotlin-lsp-VER-linux-x64.zip -> kotlin-server-VER.tar.gz). Bumping
    # requires updating modules/dev/python/build/default.nix or wherever
    # kotlin-lsp is fetched (URL + archive type). Holding at 262.2310.0
    # until the build script is reworked.
    kotlin-lsp = {
      source = "github-release";
      repo = "Kotlin/kotlin-lsp";
      version = "262.2310.0";
      tagPrefix = "kotlin-lsp/v";
      hash = "sha256-wAQkIVj0teHZF93YSOb2onlIT6WKPivOiEa4B9GtFrE=";
    };

    gurk = {
      source = "github-release";
      repo = "boxdot/gurk-rs";
      version = "0.9.3";
      tagPrefix = "v";
      hash = "sha256-ZFSUnZlp+BGIfJGs8V/K2YSmBtJrvmjplmRhxlC0o7g=";
    };

    graymatter = {
      source = "github-release";
      repo = "angelnicolasc/graymatter";
      version = "0.5.1";
      tagPrefix = "v";
      hash = "sha256-DCi5T2OpYb2sQiQB3b3BXtN8CMKaZdab0BFweeuez08=";
      vendorHash = "sha256-BLw8PXM3D+1Go/pPnJRaqXAc3wgyLI71LFmOtQYUol0=";
    };

    crawl4ai = {
      source = "github-release";
      repo = "unclecode/crawl4ai";
      version = "0.8.5";
      tagPrefix = "v";
      hash = "sha256-y5Nve8e41+wcTlymL6bXxPCwmN8+8/YvHYLGO3x4M+Q=";
    };

    skillfish = {
      source = "npm";
      repo = "knoxgraeme/skillfish";
      npmPkg = "skillfish";
      version = "1.0.37";
      hash = "sha256-4XmyKjrxm3LgjxF9so3hiD1F0ZufYY6osj3YQlE+fOo=";
      npmDepsHash = "sha256-P3J4+OiMaucsNjCaWtMTc8zlGT4fA+ItFy/D6RhBWJ0=";
    };

    todoist-cli = {
      source = "npm";
      repo = "Doist/todoist-cli";
      npmPkg = "@doist/todoist-cli";
      version = "1.61.2";
      hash = "sha256-fC4/nZ1mj1v8h97NOn7TA4nG7oOLKeeQCRtnKQ1VfoQ=";
      npmDepsHash = "sha256-n+lu7f2rsMEOCnzj1nmzGRZo3WcwhBUeamTexCOs0xM=";
    };

    yaml-schema-router = {
      source = "github-release";
      repo = "tepea-code/yaml-schema-router";
      version = "0.2.0";
      tagPrefix = "v";
      # Source build via buildGoModule; `hash` is the GitHub source archive
      # for the tag. Upstream has no external Go deps (pure stdlib), so
      # vendorHash is null.
      hash = "sha256-GFe5NPW8nxv+bQsG5G26WCf2Z6qrW1WAZBMWFZD8MFI=";
      vendorHash = null;
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
      # Pinned to 12.5.0: 12.6.0 ships a main-process logger that crashes on
      # `write EPIPE` when stdout has no live reader (desktop-file launch).
      # Filed upstream at Kong/insomnia; re-bump once they ship a fix.
      version = "12.5.0";
      tagPrefix = "core@";
      platformHashes = {
        x86_64-linux = "sha256-RYNzOX9WRPqPUMhbG/Ab4Ip25imudNGlHX1kPLzuQ+U=";
        aarch64-darwin = ""; # placeholder -- no darwin builds currently used
        x86_64-darwin = ""; # placeholder -- no darwin builds currently used
      };
    };

    # Insomnia 13 -- runs side-by-side with the pinned 12.x stable above.
    # Promoted from the 13.0.0-beta.0 prerelease once 13.0.0 went GA
    # (2026-06-16); kept as a distinct `insomnia-beta` binary with its own
    # ~/.config/insomnia-beta data dir so existing v13 data and the
    # side-by-side workflow are preserved.
    # updatePolicy = "manual": auto-bump can't track this entry independently of
    # stable (same repo). Bump by hand: set version, clear platformHashes, rebuild.
    insomnia-beta = {
      source = "github-release";
      repo = "Kong/insomnia";
      version = "13.0.0";
      tagPrefix = "core@";
      updatePolicy = "manual";
      platformHashes = {
        x86_64-linux = "sha256-PlcKBQnkmgU/SsLRKX7ohrGHm7B4hK9FMkplwlbFolI=";
        aarch64-darwin = ""; # placeholder -- no darwin builds currently used
        x86_64-darwin = ""; # placeholder -- no darwin builds currently used
      };
    };

    helium = {
      source = "github-release";
      repo = "imputnet/helium-linux";
      version = "0.12.1.1";
      tagPrefix = "";
      hash = "sha256-+UE+JqQtxbA5szPvAohapXlES21VBOdNsV6Ej1dRRfs=";
    };

    nimbalyst = {
      source = "github-release";
      repo = "Nimbalyst/nimbalyst";
      version = "0.60.1";
      tagPrefix = "v";
      hash = "sha256-ktSmye4Bn62KIu3NMFgh2rECAJNJluz1r8zilwSQs78=";
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
