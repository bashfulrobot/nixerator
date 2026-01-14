# Version Tracking for Local Package Overrides

This document tracks version bumps for locally maintained package overrides in the
nixerator repository. These overrides allow running the latest versions of packages
before they're merged into nixpkgs.

## Why Local Overrides?

Local package overrides serve several purposes:
1. **Immediate access** to new versions without waiting for nixpkgs PR review (1-7 days)
2. **Testing** new versions before contributing to nixpkgs
3. **Maintaining** packages you use heavily
4. **Contributing** back to nixpkgs once tested locally

## Workflow

```
1. New upstream release
   ↓
2. Update local override (packages/<name>/default.nix)
   ↓
3. Test locally on your systems
   ↓
4. Submit PR to nixpkgs (parallel with step 3)
   ↓
5. When nixpkgs merges PR → Remove local override (optional)
```

## Tracked Packages

### Insomnia

**Current Local Version:** 12.2.0
**Last Updated:** 2026-01-14
**Nixpkgs Version:** 11.6.0
**Pending Nixpkgs PR:** [#480124](https://github.com/NixOS/nixpkgs/pull/480124)
**Upstream Releases:** https://github.com/Kong/insomnia/releases

**Files:**
- Package: `packages/insomnia/default.nix`
- Module: `modules/apps/gui/insomnia/default.nix`

**Next Check:** Monthly (around the 15th)

**Version Bump Process:** See section below

---

## Version Bump Process

### For Insomnia (and similar packages)

#### 1. Check for New Release

```bash
# Open upstream releases page
xdg-open https://github.com/Kong/insomnia/releases

# Or use gh CLI
gh release list --repo Kong/insomnia --limit 5
```

#### 2. Update Local Package

Edit `packages/insomnia/default.nix`:

```nix
# Update version number
version = "X.Y.Z";

# Update hashes for all platforms
# Method 1: Use lib.fakeHash, then build to get real hash
# Method 2: Use nix-prefetch-url

# For x86_64-linux:
nix-prefetch-url https://github.com/Kong/insomnia/releases/download/core%40X.Y.Z/Insomnia.Core-X.Y.Z.AppImage

# For Darwin:
nix-prefetch-url https://github.com/Kong/insomnia/releases/download/core%40X.Y.Z/Insomnia.Core-X.Y.Z.dmg

# Convert to SRI format:
nix hash convert --hash-algo sha256 <hash-output>
```

**Or use Claude Code:**
```
Update packages/insomnia/default.nix to version X.Y.Z and fetch the correct hashes
```

#### 3. Update Documentation

Update the following locations with new version info:

1. `packages/insomnia/default.nix` - Top comment block
2. `modules/apps/gui/insomnia/default.nix` - Comment header
3. This file (`VERSION-TRACKING.md`) - "Tracked Packages" section

#### 4. Test Locally

```bash
# Rebuild your system
sudo nixos-rebuild switch --flake .#<hostname>

# Test the application
insomnia --version

# Verify it launches without errors (or same errors as before)
insomnia
```

#### 5. Submit to Nixpkgs

Follow the process in `/home/dustin/dev/nix/nixpkgs-version-bump.txt`:

```bash
cd ~/dev/nix/nixpkgs

# Update the nixpkgs package
# ... (follow full process in nixpkgs-version-bump.txt)

# Create PR
gh pr create --repo NixOS/nixpkgs ...
```

#### 6. Update PR Link

Once PR is created, update:
- This file's "Tracked Packages" section
- `packages/insomnia/default.nix` header comment
- `modules/apps/gui/insomnia/default.nix` header comment

#### 7. Monitor PR Status

Check PR status:
```bash
gh pr view <PR-number> --repo NixOS/nixpkgs
```

#### 8. Cleanup (Optional)

Once nixpkgs PR is merged:

**Option A: Keep local override** (for future quick updates)
- Update comments to note nixpkgs is now at same version
- Keep override in place for next version bump

**Option B: Remove local override** (rely on nixpkgs)
- Remove the overlay line from `lib/mkHost.nix`
- Keep package files for reference or delete them
- Module will use nixpkgs version automatically

## Finding Packages That Need Updates

### Manual Method

Check TODO comments in code:
```bash
cd ~/dev/nix/nixerator
grep -r "TODO.*version" packages/
grep -r "TODO.*Check for new" packages/
```

### Automated Method (Future Enhancement)

Create a script that:
1. Parses current versions from `packages/*/default.nix`
2. Checks upstream releases via GitHub API
3. Reports outdated packages

Example script location: `scripts/check-versions.sh`

## Adding New Local Overrides

To add a new package override:

### 1. Create Package Directory

```bash
mkdir -p packages/<package-name>
```

### 2. Create Package File

Create `packages/<package-name>/default.nix`:

```nix
# Local override for <Package Name>
# TODO: Check for new releases periodically at: <upstream-url>
# Last updated: <date>
# Current version: <version>
# Nixpkgs PR: <url-if-exists>

{ lib, stdenv, fetchurl, ... }:

stdenv.mkDerivation rec {
  pname = "<package-name>";
  version = "<version>";

  # ... rest of derivation
}
```

### 3. Add to Overlay

Edit `lib/mkHost.nix` and add to the overlay:

```nix
nixpkgs.overlays = [
  (final: prev: {
    insomnia = prev.callPackage ../packages/insomnia { };
    <package-name> = prev.callPackage ../packages/<package-name> { };  # Add this
  })
];
```

### 4. Create Module (Optional)

If you want a dedicated enable option:

```bash
mkdir -p modules/apps/<category>/<package-name>
```

Create `modules/apps/<category>/<package-name>/default.nix` following the
pattern in `modules/apps/gui/insomnia/default.nix`.

### 5. Document Here

Add entry to "Tracked Packages" section above.

## Best Practices

1. **Comment thoroughly** - Future you will thank present you
2. **Add TODO comments** - Makes finding packages to update easier
3. **Test locally first** - Before submitting to nixpkgs
4. **Update all docs** - Keep this file, package comments, and module comments in sync
5. **Link PRs** - Always reference nixpkgs PRs in comments
6. **Check monthly** - Set a recurring reminder to check for updates
7. **Clean commit messages** - Follow nixpkgs conventions even for local changes

## Maintenance Schedule

**Monthly checks (around 15th of each month):**
- Insomnia
- (Add other packages as you override them)

**Check method:**
```bash
# Set a calendar reminder with this command:
cd ~/dev/nix/nixerator && grep -r "TODO.*Check for new" packages/
```

## Troubleshooting

### Build Fails After Version Bump

1. **Check hash mismatch** - Error message shows correct hash
2. **Check build dependencies** - New version might need new inputs
3. **Check nixpkgs** - Might need newer nixpkgs for new dependencies
4. **Check upstream** - Version might be broken

### Module Not Using Override

1. **Check overlay is applied** - Verify in `lib/mkHost.nix`
2. **Rebuild system** - `sudo nixos-rebuild switch --flake .#<hostname>`
3. **Check package name** - Must match exactly in overlay and package

### Want to Revert to Nixpkgs Version

Comment out the package line in overlay:
```nix
nixpkgs.overlays = [
  (final: prev: {
    # insomnia = prev.callPackage ../packages/insomnia { };  # Commented out
  })
];
```

Then rebuild.

## References

- Nixpkgs version bump process: `/home/dustin/dev/nix/nixpkgs-version-bump.txt`
- Your nixpkgs fork: https://github.com/bashfulrobot/nixpkgs
- Your previous PRs: [#443207](https://github.com/NixOS/nixpkgs/pull/443207), [#480124](https://github.com/NixOS/nixpkgs/pull/480124)
