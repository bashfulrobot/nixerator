# localsend-rs upstream fixes

## 1. Cargo.toml / Cargo.lock version mismatch for `colored`

**Commit that broke it:** `ee83242d` (feat(iroh): add multi-file transfer support using collections)

**Problem:** `Cargo.toml` specifies `colored = { version = "3.1", optional = true }` but `Cargo.lock` still pins `colored 3.0.0`. This causes build failures in environments that enforce manifest/lockfile consistency (e.g., Nix `buildRustPackage`).

**Fix:** Either:
- Bump `Cargo.lock` to match: `cargo update -p colored`
- Or relax `Cargo.toml` back to `colored = { version = "3.0", optional = true }`

Running `cargo update -p colored` is the correct approach since 3.1 was the intended upgrade.

## 2. No tagged releases

**Problem:** The repo has zero git tags or GitHub releases. This makes it impossible for downstream packagers to pin to stable versions. The `Cargo.toml` declares `version = "0.1.2"` but there's no corresponding `v0.1.2` tag.

**Fix:** Tag releases with semver tags matching `Cargo.toml` version:
```
git tag v0.1.2
git push origin v0.1.2
```

Also consider creating GitHub releases with pre-compiled binaries for common platforms (x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin) via a CI workflow.

## 3. No flake.nix

**Problem:** No Nix flake, so downstream Nix users must write their own derivation.

**Fix:** Add a `flake.nix` with a `packages.default` output using `rustPlatform.buildRustPackage`. Example:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in {
        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "localsend-rs";
          version = "0.1.2";
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;
          buildFeatures = [ "all" ];
          meta.mainProgram = "localsend-rs";
        };
      });
}
```

## 4. No CI

**Problem:** No GitHub Actions workflow to catch issues like the colored version mismatch.

**Fix:** Add a basic `.github/workflows/ci.yml` that runs `cargo build --features all` and `cargo test` on push/PR.
