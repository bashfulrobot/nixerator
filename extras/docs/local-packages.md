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

## Updating Packages

```bash
just setup::check-updates          # check all packages, cache results
just setup::update-pkg <name>      # prefetch + write new version for one package
just setup::update-pkg --all       # update all release-tracked packages
just setup::update-pkg --all --include-commits   # also update commit-pinned packages
just qr                            # rebuild to verify
```
