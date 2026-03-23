# Centralized Version Management

## Problem

12 pinned packages across the repo, but version info is split between `settings/versions.nix` (6 packages) and inline pins in build files (6 more). The update-checking script only covers 6 of 12. Documentation contradicts the centralization goal. No automated prefetch/update tooling beyond a GSD-specific script.

## Design

### versions.nix Schema

Every pinned package gets a self-describing entry in `settings/versions.nix`. Three source types drive the update checker:

- `github-release` -- checks GitHub releases API, strips `tagPrefix` from tag to compare versions
- `npm` -- checks npm registry, uses `npmPkg` when the registry name differs from the key
- `github-commit` -- compares pinned rev against latest commit on default branch, reports age and commits behind

Categories: `cli`, `gui`, `fish-plugins`.

Entry fields:

- `version` (string) -- semver for release-tracked packages
- `source` (string) -- one of `github-release`, `npm`, `github-commit`, `sourcehut`
- `repo` (string) -- `owner/repo` for GitHub, or full identifier for other forges
- `tagPrefix` (string, optional) -- stripped from git tag to extract version (e.g., `"v"`, `"core@"`, `""`)
- `hash` (string) -- main source hash
- `hashes` (attrset, optional) -- per-platform hashes when needed (e.g., insomnia: `{ linux = "..."; darwin = "..."; }`)
- `npmPkg` (string, optional) -- npm registry package name when it differs from the key
- `npmDepsHash` (string, optional) -- for npm-based packages
- `rev` (string, optional) -- commit hash for `github-commit` source type
- `vendorHash` (string, optional) -- for Go modules with vendored deps

All 12 packages:

**cli:** amber, cpx, meetsum, yepanywhere, get-shit-done, superpowers, kubernetes-mcp-server, lswt, lazyrestic

**gui:** insomnia, helium

**fish-plugins:** zoxide-fish

### Build File Migration

Every `build/default.nix` imports from `versions.nix` instead of pinning inline. Files already reading from versions.nix get minor adjustments for schema changes. Files to migrate: insomnia, helium, kubernetes-mcp-server, lswt, lazyrestic, zoxide.

### Tooling

**a) `extras/scripts/nix-to-json.nix`**

Tiny Nix expression: `builtins.toJSON (import ../settings/versions.nix)`. Called via `nix eval` to give bash structured data.

**b) `extras/scripts/check-pkg-updates.bash` (rewrite)**

1. Calls `nix eval` to get all entries as JSON
2. Iterates every entry, dispatches by `source` type
3. `github-release`: hits GitHub releases API, compares versions
4. `npm`: hits npm registry, compares versions
5. `github-commit`: fetches latest commit on default branch, compares rev; if different, shows age of pinned commit and commits behind
6. Writes results to `/tmp/nixerator-pkg-status.json`
7. Prints human-readable summary to stdout

**c) `extras/scripts/update-pkg.bash` (new)**

1. Takes a package name or `--all`
2. Reads cached status or runs fresh check
3. Prefetches new hash, writes version+hash to `versions.nix`
4. For npm packages: regenerates `package-lock.json` and updates `npmDepsHash`
5. `--all` skips `github-commit` packages unless `--include-commits` is passed

Replaces the existing `update-gsd.bash`.

### Justfile Recipes

| Recipe                   | Description                                     |
| ------------------------ | ----------------------------------------------- |
| `just check-updates`     | Run check script, cache results, print report   |
| `just update-pkg <name>` | Prefetch and write new version for one package  |
| `just update-pkg --all`  | Update all available (release-based by default) |

### Rebuild Integration

Non-quiet rebuild recipes (`just rebuild`, `just switch`) print cached update report at the end if `/tmp/nixerator-pkg-status.json` exists and is less than 24 hours old.

Quiet recipes (`just qr`, `just qu`) do not print the report.

### Documentation Updates

- `extras/docs/local-packages.md` -- rewrite to reflect centralized versions.nix, explain schema, document update workflow
- `extras/docs/commands.md` -- add check-updates, update-pkg recipes

## Scope Exclusions

- Flake inputs: managed separately via `nix flake update` and upgrade recipes
- Auto-rebuild after update: user controls when to rebuild with `just qr`
