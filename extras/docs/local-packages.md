# Module-Local Packages

Package derivations live next to the modules that consume them:

- `modules/apps/cli/amber/build/default.nix`
- `modules/apps/cli/claude-code/build/default.nix` (kubernetes-mcp-server)
- `modules/apps/cli/claude-code/build/gsd/default.nix`
- `modules/apps/cli/cpx/build/default.nix`
- `modules/apps/cli/lswt/build/default.nix`
- `modules/apps/cli/meetsum/build/default.nix`
- `modules/apps/cli/restic/build/lazyrestic.nix`
- `modules/apps/cli/yepanywhere/build/default.nix`
- `modules/apps/gui/helium/build/default.nix`
- `modules/apps/gui/insomnia/build/default.nix`

For npm-based packages, lockfiles are colocated in the same module folder.

## Version Management

All versions and hashes are centralized in `settings/versions.nix`. Build files import from there and never pin versions inline.

Each entry in versions.nix is self-describing with a `source` field that tells the update tooling how to check for updates:

- `github-release` -- packages with tagged GitHub releases
- `npm` -- packages published to the npm registry
- `github-commit` -- packages pinned to a specific commit (no releases)
- `sourcehut` -- SourceHut-hosted packages (manual checking)

## Adding a New Package

1. Add an entry to `settings/versions.nix` under the appropriate category (`cli`, `gui`, `fish-plugins`)
2. Include all required fields: `version`/`rev`, `source`, `repo`, `hash`, and any optional fields (`tagPrefix`, `npmPkg`, `npmDepsHash`, `vendorHash`, `platformHashes`)
3. In your build file, add `versions` to the function arguments and reference fields via `versions.<category>.<name>`
4. In the parent module's `callPackage` call, pass `{ inherit versions; }`

## Scaffolding With nix-init

`nix-init` (enabled via `apps.cli.nix-init`, on through the dev suite) generates a
starting derivation from a URL: it detects the build system, prefetches the source
hash, and infers dependency hashes (`cargoHash`, `vendorHash`, Python deps). It is an
authoring aid, not a build-time abstraction, and nothing in the existing fleet depends
on it.

Use it when adding a **source build from a forge** (Rust/Go/Python from GitHub,
SourceHut, crates.io). It saves little for prebuilt-binary, AppImage, or npm-registry
packages, which have no build system to detect and no deps to hash.

Its raw output **fights two repo conventions**, so always adapt it:

- It inlines `version` and `hash` in the derivation. This repo centralizes both in
  `settings/versions.nix`. Move them there and reference via `versions.<cat>.<name>`.
- It wires `passthru.updateScript = nix-update-script {}`. This repo updates through
  `just setup::update-pkg`. Drop the passthru.

Workflow:

```bash
nix-init -u <url> /tmp/scaffold.nix    # generate a draft, do not write into the tree
```

Then: add the version/hash entry to `settings/versions.nix`, move the draft into
`modules/apps/<cli|gui>/<name>/build/default.nix`, strip inline pins and the update
script, and follow "Adding a New Package" above. The tool's config lives in
`modules/apps/cli/nix-init/default.nix` (maintainer stamp, flake-registry nixpkgs since
this host runs `nixPath = [ ]`, and `commit = false`).

## Updating Packages

```bash
just setup::check-updates          # check all packages, cache results
just setup::update-pkg <name>      # prefetch + write new version for one package
just setup::update-pkg --all       # update all release-tracked packages
just setup::update-pkg --all --include-commits   # also update commit-pinned packages
just qr                            # rebuild to verify
```
