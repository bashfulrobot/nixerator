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
  #   updatePolicy - "manual" excludes the entry from `just setup::update-pkg`
  #                  and `check-updates`. Use it for ANY entry auto-bump cannot
  #                  correctly complete, and say why in a comment above.
  #
  # IMPORTANT: a comment is not a pin. update-pkg reads this file as data, so a
  # "# Pinned to X, do not bump" note above an entry does nothing to stop it.
  # Anything that must not auto-bump needs updatePolicy = "manual". Known cases:
  #   - a deliberate hold on a known-bad upstream release. Set updatePolicy AND
  #     say why; drop both once upstream fixes it, so holds don't outlive their
  #     reason (insomnia was held at 12.5.0 for an EPIPE crash until 13.0.2).
  #   - prerelease/nightly channels: update-pkg follows GitHub
  #     /releases/latest, which only ever returns stable      e.g. brave-origin
  #   - URLs built from fields update-pkg doesn't track       e.g. salesforce-cli
  #     (shortRev)
  #   - npm packages with a vendored package-lock.json, since
  #     the lock + npmDepsHash must be regenerated together   e.g. todoist-cli, reap
  #   - archived modules that nothing imports/builds          e.g. graymatter
  #   - artifacts hosted off-GitHub whose naming can drift
  #     independently of the release tag                      e.g. kotlin-lsp

  cli = {
    agent-scan = {
      source = "github-release";
      repo = "snyk/agent-scan";
      version = "0.5.15";
      tagPrefix = "v";
      platformHashes = {
        x86_64-linux = "sha256-9H3ubHfTM0k9CMvNn4pZ9NSCP3LEp1KWRjxfzpS68yI=";
        aarch64-darwin = "sha256-pHLgI5qb2xBH2CGMPCHO625sbCJuZ6WHWG+H6MHYXxQ=";
        x86_64-darwin = "sha256-XG5YlWfewtknwz9OBKgByiT5dhj7SUfkuGFNW6NgB2M=";
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

    # updatePolicy=manual: the asset URL embeds `shortRev`, a per-release build id
    # (sf-v<version>-<shortRev>-linux-x64.tar.xz). update-pkg has no concept of
    # shortRev, so it bumps `version` alone and leaves shortRev pointing at the
    # previous release, producing a 404. Bump this by hand: read the real asset
    # name off the GitHub release and update version + shortRev together.
    salesforce-cli = {
      source = "github-release";
      repo = "salesforcecli/cli";
      updatePolicy = "manual";
      version = "2.145.0";
      tagPrefix = "";
      shortRev = "e380bec";
      hash = "sha256-5CJX6rmCMatYIDavUdpupEdQiXEaoH//tfPHuRwmAm0=";
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
      version = "0.0.65";
      hash = "sha256-pixDT+okUD6OMqWdkLrJ91yYSSqcgd5nmEyegfN6uJ8=";
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

    # HELD at 0.16.4. Like todoist-cli, this vendors build/reap/package-lock.json
    # (still at 0.16.4) and `npm ci` rejects a lock/package version mismatch.
    # update-pkg does not regenerate vendored locks, so bumping means refreshing
    # the lock and npmDepsHash by hand. updatePolicy=manual stops the tool
    # proposing a bump it cannot actually complete.
    reap = {
      source = "npm";
      repo = "c-d-cc/reap";
      npmPkg = "@c-d-cc/reap";
      updatePolicy = "manual";
      version = "0.16.4";
      hash = "sha256-ABgVEgvlYrPZh9MzTpNlTZp7jfhsOjFlloU0Rltkkio=";
      npmDepsHash = "sha256-Hdf0YhSTfUUeTnfMKrokdAha8Vw70WMB0BS8OIpArEI=";
    };

    # HELD at 262.2310.0 (this note supersedes the earlier "262.4739.0 is
    # available but upstream renamed assets" one; same root cause, still true).
    # The version is read from GitHub releases, but the artifact comes from
    # JetBrains' CDN, and upstream restructured both the CDN path and the
    # artifact name: 262.2310.0 is published as
    # /kotlin-lsp/<v>/kotlin-lsp-<v>-linux-x64.zip, while 262.8190.0 moved to
    # /language-server/kotlin-server/<v>/kotlin-server-<v>... and publishes no
    # linux-x64 zip we can find (its release notes list Windows builds only).
    # Every URL shape probed for 262.8190.0 returns 404, so a bump needs
    # build/default.nix's URL reworked AND a linux artifact to exist upstream.
    # updatePolicy=manual makes the hold stick: it was a comment-only hold
    # before, which update-pkg cannot read, so the tool bumped it regardless.
    kotlin-lsp = {
      source = "github-release";
      repo = "Kotlin/kotlin-lsp";
      updatePolicy = "manual";
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

    "iso-topology" = {
      source = "github-release";
      repo = "bashfulrobot/iso-topology"; # fork of MarkovWangRR/iso-topology; audited at v0.15.0
      version = "0.15.0";
      tagPrefix = "v";
      hash = "sha256-nOn144kK6iFvuDOzTGhaX5p5YRHTO2NWFD6xRk1UDW0=";
      vendorHash = "sha256-V/8PjfqwofxIXY89reSu3sY3UAMOxApzYCwqCwYMxh8=";
    };

    # graymatter now lives in modules/archive/, which modules/default.nix excludes
    # from auto-import, so nothing builds it and a cleared hash here can never be
    # resolved by a rebuild. update-pkg has no notion of archived modules and will
    # keep offering the bump; leave this entry pinned to its last-built values.
    graymatter = {
      source = "github-release";
      repo = "angelnicolasc/graymatter";
      updatePolicy = "manual";
      version = "0.5.1";
      tagPrefix = "v";
      hash = "sha256-DCi5T2OpYb2sQiQB3b3BXtN8CMKaZdab0BFweeuez08=";
      vendorHash = "sha256-BLw8PXM3D+1Go/pPnJRaqXAc3wgyLI71LFmOtQYUol0=";
    };

    skillfish = {
      source = "npm";
      repo = "knoxgraeme/skillfish";
      npmPkg = "skillfish";
      version = "1.0.38";
      hash = "sha256-oe1j2O5a2hF6Q8oP5RLnx0kDwew/AHnMJMIcfVgc+Oo=";
      npmDepsHash = "sha256-P3J4+OiMaucsNjCaWtMTc8zlGT4fA+ItFy/D6RhBWJ0=";
    };

    todoist-cli = {
      source = "npm";
      repo = "Doist/todoist-cli";
      npmPkg = "@doist/todoist-cli";
      # updatePolicy=manual: build/package-lock.json is vendored (the published
      # npm tarball ships none), and update-pkg does not regenerate vendored
      # locks. A version bump here is never just a version bump -- see the
      # regeneration recipe in build/default.nix. Auto-bumping would leave the
      # lock behind and `npm ci` would reject the mismatch.
      updatePolicy = "manual";
      version = "3.0.0";
      hash = "sha256-zbnaRInpMsKKQkQOAUnzSTki4BGR6htZ/7mP0/OEbX4=";
      npmDepsHash = "sha256-B0okAgIvprmXiejL3KOBEw1sBtTUwt8NpGYs76g1wT0=";
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
    # Claude desktop app (Electron). Anthropic ships it only as a Debian .deb
    # from their apt repo; nixpkgs has no derivation, so the build
    # (modules/apps/gui/claude-desktop/build) unpacks the .deb and patchelfs
    # the bundled Electron (slack-style). The `apt` source type teaches the
    # update tooling to read the apt Packages index and prefetch from the pool.
    # `aptRepo` + `package` are the single source of truth for the .deb URL,
    # consumed by both the build and scripts/{check,update}-pkg.
    claude-desktop = {
      source = "apt";
      aptRepo = "https://downloads.claude.ai/claude-desktop/apt/stable";
      package = "claude-desktop";
      version = "1.22209.0";
      hash = "sha256-bRiueSwr3a0B7cl8LD9M9IkATO/o/tZ2Cmlu0lxJv2E=";
    };

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
      # Was pinned to 12.5.0 because 12.6.0 shipped a main-process logger that
      # crashed on `write EPIPE` when stdout had no live reader (desktop-file
      # launch). 13.0.2 fixes it, so the pin is lifted and this tracks latest
      # again. No updatePolicy: nothing structural stops auto-bump here.
      version = "13.0.2";
      tagPrefix = "core@";
      platformHashes = {
        x86_64-linux = "sha256-lEEN23hkdpHn3DyyMEhz5rp5F5CURZGPUTdX0A9QuTU=";
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
      version = "0.14.6.1";
      tagPrefix = "";
      hash = "sha256-qdM1Qysx5OOBwzr6A6tyPIfZcHxn2YkIPedGelvbk7I=";
    };

    # Brave Origin — minimalist standalone Brave. Only the nightly channel
    # ships Linux artifacts. Asset: brave-origin-nightly-<version>-linux-amd64.zip
    # under release tag v<version>. The package build (modules/apps/gui/
    # brave-origin/build) consumes this entry.
    # NOTE: `update-pkg` follows GitHub's "latest release", which is the STABLE
    # channel (v1.92.140 at time of writing). This package tracks NIGHTLY, and
    # its build hardcodes a `nightly` infix in the asset name, so a stable
    # version both goes backwards (nightly 1.94.x leads stable 1.92.x) and 404s
    # on fetch. Keep this pinned to a nightly tag and re-check it by hand after
    # running update-pkg. Stable now does ship Linux zips, so migrating this off
    # nightly is possible, but it needs the asset name in build/default.nix
    # changed too; that is a deliberate choice, not an auto-update.
    brave-origin = {
      source = "github-release";
      repo = "brave/brave-browser";
      updatePolicy = "manual";
      version = "1.94.77";
      tagPrefix = "v";
      hash = "sha256-SIpt34JFvvXo+joxKZzu7V1CktrAqUuRmI/0UjnueKA=";
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
