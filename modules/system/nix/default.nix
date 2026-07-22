{
  lib,
  pkgs,
  secretsLib,
  globals,
  ...
}:

{

  nix = {
    nixPath = [ ];

    settings = {
      # 4 jobs × 2 cores = 8 threads (half of 16), keeps desktop responsive
      max-jobs = 4;
      cores = 2;

      substituters = [
        "https://hyprland.cachix.org"
        "https://cache.numtide.com"
        # "https://zed.cachix.org"
        "https://cache.garnix.io"
      ];

      trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        # "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      ];
    };

    # GitHub access-token for private flake inputs. Materialised at system
    # activation into a root-only 0600 file and pulled in via nix.conf
    # `!include` (an optional include the nix daemon reads at runtime), so it
    # stays out of the world-readable /etc/nix/nix.conf and out of the store
    # (issue #265). `!include` no-ops when the file is absent, so no host guard
    # is needed here.
    extraOptions = ''
      !include /run/nixos-secrets/nix-access-tokens.conf
    '';
  };

  systemd.tmpfiles.rules = [ "d /run/nixos-secrets 0755 root root -" ];

  system.activationScripts.nixAccessToken = lib.stringAfter [ "etc" ] (
    secretsLib.installValue {
      jq = "${pkgs.jq}/bin/jq";
      secretsFile = secretsLib.file globals;
      path = ".github.accessToken";
      dest = "/run/nixos-secrets/nix-access-tokens.conf";
      mode = "0600";
      prefix = "access-tokens = github.com=";
      suffix = "\n";
    }
  );

  # Recent crates.io enforcement of their data-access policy
  # (https://crates.io/data-access) returns HTTP 403 for the default
  # `curl/<v> Nixpkgs/<v>` User-Agent that nixpkgs' `fetchurl` builder
  # emits (pkgs/build-support/fetchurl/builder.sh, around the curl array
  # at line ~29). This breaks every `cargoLock.lockFile`-based Rust
  # package whose vendored crates aren't already cached, including
  # voxtype (the failing build on donkeykong). See
  # rust-lang/crates.io#13482 and NixOS/nixpkgs#524979.
  #
  # nixpkgs commit f830e61 ("rustPlatform.importCargoLock: download
  # crates from static.crates.io", 2026-05-27) fixes this upstream by
  # switching the registry URL to the CDN, but the `nixos-unstable`
  # channel we follow hasn't picked it up yet.
  #
  # The fetchurl builder allows admins to extend curl's argument list
  # via `NIX_CURL_FLAGS` — it's whitelisted in fetchurl's
  # `impureEnvVars` (pkgs/build-support/fetchurl/default.nix:76) and
  # interpolated unquoted into the curl invocation
  # (pkgs/build-support/fetchurl/builder.sh:47), so a later
  # `--user-agent` flag overrides the Nixpkgs default. Setting it on
  # the nix-daemon service environment propagates it into every
  # fixed-output fetcher sandbox without affecting the rest of the
  # build environment.
  #
  # Output integrity is still guaranteed by the fixed-output SHA256
  # — only the HTTP client signature changes, not the bytes we accept.
  # Drop this once the nixos-unstable channel advances past f830e61.
  systemd.services.nix-daemon.environment.NIX_CURL_FLAGS = "--user-agent Mozilla/5.0";
}
