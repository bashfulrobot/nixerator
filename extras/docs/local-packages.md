# Module-Local Packages

Package derivations live next to the modules that consume them:

- `modules/apps/cli/amber/build/default.nix`
- `modules/apps/cli/claude-code/build/default.nix` (kubernetes-mcp-server)
- `modules/apps/cli/claude-code/build/gsd/default.nix`
- `modules/apps/cli/cpx/build/default.nix`
- `modules/apps/cli/iso-topology/build/default.nix`
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

### Go modules (two-rebuild cycle)

When `update-pkg` bumps a Go package that has `vendorHash` in `versions.nix`, the source hash and the vendor hash must be refreshed separately. The script warns you, but will not clear `vendorHash` automatically.

After running `update-pkg <name>`:

1. In `settings/versions.nix`, set `vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";` for the package.
2. `just qr` -- fails with the correct source hash. Copy it into `hash`.
3. `just qr` -- fails with the correct vendor hash. Copy it into `vendorHash`.
4. `just qr` -- passes.

## Forked Packages

Some packages are pinned through a personal fork rather than the upstream repo. The fork is used when the upstream author is unverified or the supply-chain risk warrants an audit gate before pulling in changes.

Current forked packages:

| Package | Fork | Upstream | Audited at |
|---------|------|----------|------------|
| iso-topology | `bashfulrobot/iso-topology` | `MarkovWangRR/iso-topology` | v0.15.0 |

### Why fork instead of pointing directly at upstream

A fork gives a fixed, auditable point in the graph. The `repo` field in `versions.nix` points to the fork, so `check-updates` and `update-pkg` operate against controlled releases on that fork. Nothing changes unless you explicitly pull from upstream and tag the fork.

### Security-sensitive files for iso-topology

Before accepting any upstream release, diff these three files between the old and new version:

- `icons.go` -- contains `inlineLocalIcon`, which reads arbitrary image files from the filesystem via the `icon:` DSL field. Watch for new read paths or any exec calls.
- `cmd/isotopo-mcp/main.go` -- the MCP server entry point. Watch for new tools, new shell exec calls, or changes to the `output_dir` parameter (which controls write targets).
- `go.mod` -- tracks all transitive dependencies. Watch for new modules that weren't there before.

If any of these change in a way that expands attack surface, read the full diff before proceeding.

### Updating a forked package

```bash
# 1. Check whether upstream has a new release
gh release list -R MarkovWangRR/iso-topology --limit 5

# 2. Review the diff on the three sensitive files between old and new version
#    (substitute OLD and NEW version tags)
gh api repos/MarkovWangRR/iso-topology/compare/vOLD...vNEW \
  --jq '.files[] | select(.filename | test("icons.go|cmd/isotopo-mcp/main.go|go.mod")) | .filename'

# 2a. Run govulncheck against the new source tree to catch CVEs in transitive deps
#     (requires govulncheck: nix shell nixpkgs#govulncheck)
cd /tmp && gh repo clone MarkovWangRR/iso-topology iso-topology-audit -- --branch vNEW --depth 1
cd iso-topology-audit && govulncheck ./...
cd /tmp && rm -rf iso-topology-audit

# 3. If the diff is acceptable, sync the fork's default branch
gh repo sync bashfulrobot/iso-topology

# 4. Create a matching release on the fork (this creates the tag the update
#    scripts look for)
gh release create vNEW \
  --repo bashfulrobot/iso-topology \
  --title "vNEW" \
  --notes "Synced from upstream MarkovWangRR/iso-topology vNEW. Audited: icons.go, cmd/isotopo-mcp/main.go, go.mod."

# 5. In settings/versions.nix set vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
#    then run the standard update workflow
just setup::update-pkg iso-topology   # bumps version, clears source hash
just qr                                # get correct source hash, update versions.nix
just qr                                # get correct vendor hash, update versions.nix
just qr                                # passes
```

After the rebuild passes, update the `# fork of ...; audited at vNEW` comments in both `settings/versions.nix` and `modules/apps/cli/iso-topology/build/default.nix`.
