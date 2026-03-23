# Centralized Version Management Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Centralize all 12 pinned package versions into `settings/versions.nix` with self-describing metadata, rewrite update-checking tooling to be data-driven, and add automated prefetch/update capability.

**Architecture:** `versions.nix` becomes the single source of truth for every pinned package. A small Nix helper dumps it as JSON. Bash scripts iterate the JSON to check for updates and prefetch new hashes. Build files import from versions.nix instead of pinning inline.

**Tech Stack:** Nix, Bash, jq, curl, nix-prefetch-url, nix hash convert

---

### Task 1: Expand versions.nix with all packages and self-describing metadata

**Files:**

- Modify: `settings/versions.nix`

**Step 1: Rewrite versions.nix with the new schema**

Replace the entire file with:

```nix
{
  # Centralized version management for all pinned software
  # Schema: each entry is self-describing for automated update checking
  #
  # Fields:
  #   version     - semver string (release-tracked packages)
  #   source      - "github-release" | "npm" | "github-commit" | "sourcehut"
  #   repo        - "owner/repo" for GitHub, "~owner/repo" for SourceHut
  #   tagPrefix   - stripped from git tag to extract version (e.g. "v", "core@", "")
  #   hash        - SRI hash of the main source
  #   hashes      - per-platform hashes (replaces hash when needed)
  #   npmPkg      - npm registry name when it differs from the key
  #   npmDepsHash - npm dependency hash (for buildNpmPackage)
  #   rev         - commit hash (github-commit source type)
  #   vendorHash  - Go module vendor hash

  cli = {
    amber = {
      version = "0.6.1";
      source = "github-release";
      repo = "dalance/amber";
      tagPrefix = "v";
      hash = "sha256-/PgoqEnmAawgQCcJ759sRwApWlO2qpAHj/bKYGsn+qk=";
    };

    meetsum = {
      version = "0.8.3";
      source = "github-release";
      repo = "bashfulrobot/meetsum";
      tagPrefix = "v";
      hash = "sha256-bYSk/mYor/dil/Dz4RDkRfpE0412Ue93NR5D+i73ihQ=";
    };

    cpx = {
      version = "0.1.3";
      source = "github-release";
      repo = "11happy/cpx";
      tagPrefix = "v";
      hash = "sha256-1qxQgWTxDIRabZRyE5vIo+H0ebzGGB+nyyzO2dujlK4=";
    };

    yepanywhere = {
      version = "0.4.8";
      source = "npm";
      repo = "kzahel/yepanywhere";
      npmPkg = "yepanywhere";
      hash = "sha256-ZOWI7uiU3MdYMLtamWuiSCSdrdXhrVdPIfJkPMHVtYo=";
      npmDepsHash = "sha256-X+uKkERkbQ9cxHZPag6oqcIs2exg4+ncwPwJAEe+gEc=";
    };

    get-shit-done = {
      version = "1.22.4";
      source = "npm";
      repo = "gsd-build/get-shit-done";
      npmPkg = "get-shit-done-cc";
      hash = "sha256-uW4crLjrx6i02AyoKuQb0BIJ6IIPYkmQygz/RA7Qacc=";
      npmDepsHash = "sha256-15I2dWDgJAdG1edG0e9QUvnyp3PxmZ04jTUKqTUXk1U=";
    };

    superpowers = {
      source = "github-commit";
      repo = "obra/superpowers";
      rev = "e4a2375cb705ca5800f0833528ce36a3faf9017a";
      hash = "sha256-AeICtdAfWRp0oCgQqd8LdrEWWtKNqUNWdvn0CGL18fA=";
    };

    kubernetes-mcp-server = {
      version = "0.0.57";
      source = "npm";
      repo = "containers/kubernetes-mcp-server";
      npmPkg = "kubernetes-mcp-server-linux-amd64";
      hash = "sha256-csF1HhRFqccBcu+jCkRSIhxNJhhO6jMBISL81RMlLBc=";
    };

    lswt = {
      version = "2.0.0";
      source = "sourcehut";
      repo = "~leon_plickat/lswt";
      tagPrefix = "v";
      hash = "sha256-8jP6I2zsDt57STtuq4F9mcsckrjvaCE5lavqKTjhNT0=";
    };

    lazyrestic = {
      source = "github-commit";
      repo = "craigderington/lazyrestic";
      rev = "b59e26f06da7b35f587b97cf0804b0e66b78f1e1";
      hash = "sha256-Uezahy0f1/3wnuYQscXgpb0iFXWTvP0I1V5TPcmrV3A=";
      vendorHash = "sha256-MIq04ecsWq2DEbt6myCm4VqQYqjlAmTScDv0OXm9XV4=";
    };
  };

  gui = {
    insomnia = {
      version = "12.3.1";
      source = "github-release";
      repo = "Kong/insomnia";
      tagPrefix = "core@";
      hashes = {
        x86_64-linux = "sha256-Bcja3z/QKdJ6NNvrRjSPPUsuqy53JveAiJ8jYrwg2uY=";
        aarch64-darwin = "sha256-eKHZjZ8nVRIC28LJlokWop0xHGYyYcUS6ehzu5I/8CE=";
        x86_64-darwin = "sha256-eKHZjZ8nVRIC28LJlokWop0xHGYyYcUS6ehzu5I/8CE=";
      };
    };

    helium = {
      version = "0.9.1.1";
      source = "github-release";
      repo = "imputnet/helium-linux";
      tagPrefix = "";
      hash = "sha256-0Kw8Ko41Gdz4xLn62riYAny99Hd0s7/75h8bz4LUuCE=";
    };
  };

  fish-plugins = {
    zoxide-fish = {
      version = "3.0";
      source = "github-release";
      repo = "icezyclon/zoxide.fish";
      tagPrefix = "";
      hash = "sha256-OjrX0d8VjDMxiI5JlJPyu/scTs/fS/f5ehVyhAA/KDM=";
    };
  };
}
```

**Step 2: Verify the file evaluates correctly**

Run: `nix eval --json -f settings/versions.nix`
Expected: valid JSON output containing all entries

**Step 3: Commit**

```bash
git add settings/versions.nix
```

Suggested: `feat(versions): expand versions.nix with all packages and self-describing metadata`

---

### Task 2: Migrate insomnia build to use versions.nix

**Files:**

- Modify: `modules/apps/gui/insomnia/build/default.nix`

**Step 1: Update the function signature and let-block**

The file currently has inline `version` and per-platform `src` hashes. Update it to read from `versions`:

```nix
# Local override for Insomnia API client (ahead of nixpkgs)
# Version managed in settings/versions.nix

{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  undmg,
  versions,
}:
let
  pname = "insomnia";
  v = versions.gui.insomnia;
  inherit (v) version;

  src =
    fetchurl
      {
        aarch64-darwin = {
          url = "https://github.com/Kong/insomnia/releases/download/core%40${version}/Insomnia.Core-${version}.dmg";
          hash = v.hashes.aarch64-darwin;
        };
        x86_64-darwin = {
          url = "https://github.com/Kong/insomnia/releases/download/core%40${version}/Insomnia.Core-${version}.dmg";
          hash = v.hashes.x86_64-darwin;
        };
        x86_64-linux = {
          url = "https://github.com/Kong/insomnia/releases/download/core%40${version}/Insomnia.Core-${version}.AppImage";
          hash = v.hashes.x86_64-linux;
        };
      }
      .${stdenv.system} or (throw "Unsupported system: ${stdenv.system}");
```

Keep the rest of the file (meta, darwin/linux conditionals) unchanged.

**Step 2: Verify it evaluates**

Run: `nix eval --json -f settings/versions.nix .gui.insomnia.version`
Expected: `"12.3.1"`

**Step 3: Commit**

```bash
git add modules/apps/gui/insomnia/build/default.nix
```

Suggested: `refactor(insomnia): read version from versions.nix`

---

### Task 3: Migrate helium build to use versions.nix

**Files:**

- Modify: `modules/apps/gui/helium/build/default.nix`

**Step 1: Update the function signature and let-block**

```nix
# Local package for Helium browser -- Chromium-based, privacy-focused
# Version managed in settings/versions.nix

{
  lib,
  fetchurl,
  appimageTools,
  versions,
}:
let
  pname = "helium";
  v = versions.gui.helium;
  inherit (v) version;

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    inherit (v) hash;
  };
```

Keep the rest of the file unchanged.

**Step 2: Commit**

```bash
git add modules/apps/gui/helium/build/default.nix
```

Suggested: `refactor(helium): read version from versions.nix`

---

### Task 4: Migrate kubernetes-mcp-server build to use versions.nix

**Files:**

- Modify: `modules/apps/cli/claude-code/build/default.nix`

**Step 1: Update the file**

```nix
{
  lib,
  stdenvNoCC,
  fetchurl,
  versions,
}:
let
  pname = "kubernetes-mcp-server";
  v = versions.cli.kubernetes-mcp-server;
  inherit (v) version;
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://registry.npmjs.org/kubernetes-mcp-server-linux-amd64/-/kubernetes-mcp-server-linux-amd64-${version}.tgz";
    inherit (v) hash;
  };

  unpackPhase = ''
    tar -xzf "$src"
  '';

  installPhase = ''
    mkdir -p "$out/bin"
    install -Dm755 package/bin/kubernetes-mcp-server-linux-amd64 "$out/bin/${pname}"
  '';

  meta = with lib; {
    description = "Model Context Protocol server for Kubernetes and OpenShift";
    homepage = "https://github.com/containers/kubernetes-mcp-server";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
```

**Step 2: Commit**

```bash
git add modules/apps/cli/claude-code/build/default.nix
```

Suggested: `refactor(kubernetes-mcp-server): read version from versions.nix`

---

### Task 5: Migrate lswt build to use versions.nix

**Files:**

- Modify: `modules/apps/cli/lswt/build/default.nix`

**Step 1: Update the file**

```nix
{ lib
, stdenv
, fetchFromSourcehut
, pkg-config
, wayland
, wayland-scanner
, wayland-protocols
, versions
}:

let
  v = versions.cli.lswt;
in
stdenv.mkDerivation rec {
  pname = "lswt";
  inherit (v) version;

  src = fetchFromSourcehut {
    owner = "~leon_plickat";
    repo = pname;
    rev = "v${version}";
    inherit (v) hash;
  };

  nativeBuildInputs = [
    pkg-config
    wayland-scanner
  ];

  buildInputs = [
    wayland
    wayland-protocols
  ];

  makeFlags = [
    "PREFIX=$(out)"
  ];

  meta = with lib; {
    description = "List Wayland toplevels (open windows in Wayland desktop environments)";
    homepage = "https://git.sr.ht/~leon_plickat/lswt";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [ ];
    mainProgram = "lswt";
  };
}
```

**Step 2: Commit**

```bash
git add modules/apps/cli/lswt/build/default.nix
```

Suggested: `refactor(lswt): read version from versions.nix`

---

### Task 6: Migrate lazyrestic build to use versions.nix

**Files:**

- Modify: `modules/apps/cli/restic/build/lazyrestic.nix`

**Step 1: Update the file**

```nix
{ lib, buildGoModule, fetchFromGitHub, versions }:

let
  v = versions.cli.lazyrestic;
in
buildGoModule rec {
  pname = "lazyrestic";
  version = "unstable-2025-12-30";

  src = fetchFromGitHub {
    owner = "craigderington";
    repo = "lazyrestic";
    inherit (v) rev hash;
  };

  inherit (v) vendorHash;

  # Skip tests due to filesystem-specific test dependencies
  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "A TUI for managing restic backups";
    homepage = "https://github.com/craigderington/lazyrestic";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "lazyrestic";
  };
}
```

Note: `version` stays as the human-readable `"unstable-2025-12-30"` string since this package has no releases. The `rev` and hashes come from versions.nix.

**Step 2: Commit**

```bash
git add modules/apps/cli/restic/build/lazyrestic.nix
```

Suggested: `refactor(lazyrestic): read rev and hashes from versions.nix`

---

### Task 7: Migrate zoxide.fish plugin to use versions.nix

**Files:**

- Modify: `modules/apps/cli/zoxide/default.nix`

**Step 1: Update the fish plugin block**

The file is a NixOS module, not a standalone build file. It receives `versions` via `specialArgs`. Change the `programs.fish.plugins` block:

```nix
{
  globals,
  lib,
  config,
  pkgs,
  versions,
  ...
}:

let
  cfg = config.apps.cli.zoxide;
  zfV = versions.fish-plugins.zoxide-fish;
in
{
  options = {
    apps.cli.zoxide.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable zoxide for smarter directory navigation.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Home Manager user configuration
    home-manager.users.${globals.user.name} = {

      programs.zoxide = {
        enable = true;
        # Disabled - using zoxide.fish plugin for enhanced tab completion
        enableFishIntegration = false;
      };

      # zoxide.fish provides enhanced tab completion that completes directories
      # first, then falls back to zoxide queries. Also aliases cd to z by default.
      # https://github.com/icezyclon/zoxide.fish
      programs.fish.plugins = [
        {
          name = "zoxide.fish";
          src = pkgs.fetchFromGitHub {
            owner = "icezyclon";
            repo = "zoxide.fish";
            rev = zfV.version;
            inherit (zfV) hash;
          };
        }
      ];

    };

  };
}
```

**Step 2: Commit**

```bash
git add modules/apps/cli/zoxide/default.nix
```

Suggested: `refactor(zoxide): read fish plugin version from versions.nix`

---

### Task 8: Migrate GSD npmDepsHash to versions.nix

**Files:**

- Modify: `modules/apps/cli/claude-code/build/gsd/default.nix`

**Step 1: Update the file to read npmDepsHash from versions**

The file already reads `version` and `sha256` from versions.nix but has `npmDepsHash` inline. Update:

```nix
{
  lib,
  buildNpmPackage,
  fetchurl,
  versions,
}:

buildNpmPackage rec {
  pname = "get-shit-done-cc";
  inherit (versions.cli.get-shit-done) version npmDepsHash;

  src = fetchurl {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    inherit (versions.cli.get-shit-done) hash;
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  meta = with lib; {
    description = "Meta-prompting and context engineering system for AI-assisted development";
    homepage = "https://github.com/gsd-build/get-shit-done";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = pname;
  };
}
```

Note: `sha256` is renamed to `hash` in versions.nix. Update the `inherit` accordingly.

**Step 2: Commit**

```bash
git add modules/apps/cli/claude-code/build/gsd/default.nix
```

Suggested: `refactor(gsd): read npmDepsHash from versions.nix`

---

### Task 9: Update existing build files for renamed hash key

**Files:**

- Modify: `modules/apps/cli/amber/build/default.nix`
- Modify: `modules/apps/cli/cpx/build/default.nix`
- Modify: `modules/apps/cli/meetsum/build/default.nix`
- Modify: `modules/apps/cli/yepanywhere/build/default.nix`

These files currently use `inherit (versions.cli.<name>) sha256;` but versions.nix now uses `hash` instead of `sha256`. Update each file.

**Step 1: amber -- change sha256 to hash**

In `modules/apps/cli/amber/build/default.nix`, change:

```nix
    inherit (versions.cli.amber) sha256;
```

to:

```nix
    inherit (versions.cli.amber) hash;
```

Note: `fetchurl` accepts both `sha256` and `hash`, but `hash` is the modern convention and matches our schema.

**Step 2: cpx -- same change**

In `modules/apps/cli/cpx/build/default.nix`, change `inherit (versions.cli.cpx) sha256;` to `inherit (versions.cli.cpx) hash;`

**Step 3: meetsum -- same change**

In `modules/apps/cli/meetsum/build/default.nix`, change `inherit (versions.cli.meetsum) sha256;` to `inherit (versions.cli.meetsum) hash;`

**Step 4: yepanywhere -- update hash field name**

In `modules/apps/cli/yepanywhere/build/default.nix`, change:

```nix
    inherit (versions.cli.yepanywhere) sha256;
```

to:

```nix
    inherit (versions.cli.yepanywhere) hash;
```

The `npmDepsHash` inherit already works since the field name hasn't changed.

**Step 5: Commit**

```bash
git add modules/apps/cli/amber/build/default.nix modules/apps/cli/cpx/build/default.nix modules/apps/cli/meetsum/build/default.nix modules/apps/cli/yepanywhere/build/default.nix
```

Suggested: `refactor(versions): rename sha256 to hash in all build files`

---

### Task 10: Update superpowers.nix for renamed hash key

**Files:**

- Modify: `modules/apps/cli/claude-code/cfg/superpowers.nix`

**Step 1: Verify it already uses versions.nix**

The file already reads `versions.cli.superpowers.rev` and `versions.cli.superpowers.hash`. No changes needed -- the field was already named `hash` in the old schema.

This is a no-op task. Skip to next task.

---

### Task 11: Test rebuild

**Step 1: Run a quiet rebuild to verify all build files resolve correctly**

Run: `just qr`
Expected: Rebuild succeeds. If it fails, spawn a Nix subagent to diagnose `/tmp/nixerator-rebuild.log`.

**Step 2: Commit if any fixups were needed**

---

### Task 12: Create the nix-to-json helper

**Files:**

- Create: `extras/scripts/nix-to-json.nix`

**Step 1: Write the helper**

```nix
# Evaluates versions.nix and outputs as JSON for bash tooling
# Usage: nix eval --json -f extras/scripts/nix-to-json.nix
import ../../settings/versions.nix
```

**Step 2: Verify it works**

Run: `nix eval --json -f extras/scripts/nix-to-json.nix | jq .`
Expected: Full JSON output of all version entries with metadata

**Step 3: Commit**

```bash
git add extras/scripts/nix-to-json.nix
```

Suggested: `feat(versions): add nix-to-json helper for bash tooling`

---

### Task 13: Rewrite check-pkg-updates.bash as data-driven

**Files:**

- Modify: `extras/scripts/check-pkg-updates.bash`

**Step 1: Rewrite the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Data-driven package update checker
# Reads all entries from versions.nix via nix eval, checks each by source type
# Caches results to /tmp/nixerator-pkg-status.json

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE_FILE="/tmp/nixerator-pkg-status.json"

# --- Helpers ---
info()  { echo -e "\033[1;34m[check]\033[0m $*"; }
ok()    { echo -e "\033[1;32m  ✓\033[0m $*"; }
warn()  { echo -e "\033[1;33m  ↑\033[0m $*"; }
err()   { echo -e "\033[1;31m  ✗\033[0m $*"; }

updates_found=0
results='[]'

add_result() {
    local name="$1" category="$2" current="$3" latest="$4" status="$5" detail="${6:-}"
    results=$(echo "$results" | jq --arg n "$name" --arg cat "$category" \
        --arg cur "$current" --arg lat "$latest" --arg s "$status" --arg d "$detail" \
        '. + [{"name":$n,"category":$cat,"current":$cur,"latest":$lat,"status":$s,"detail":$d}]')
}

# --- Load versions.nix as JSON ---
info "Loading versions.nix..."
versions_json=$(nix eval --json -f "$REPO_ROOT/extras/scripts/nix-to-json.nix")

# --- Check a github-release package ---
check_github_release() {
    local name="$1" category="$2" repo="$3" current="$4" prefix="$5"

    local tag
    tag=$(curl -sf "https://api.github.com/repos/$repo/releases/latest" \
        | jq -r '.tag_name // empty' 2>/dev/null) || true

    if [[ -z "$tag" ]]; then
        err "$name -- failed to fetch latest release from $repo"
        add_result "$name" "$category" "$current" "unknown" "error" "Failed to fetch release"
        return
    fi

    local latest="${tag#"$prefix"}"

    if [[ "$current" == "$latest" ]]; then
        ok "$name $current (up to date)"
        add_result "$name" "$category" "$current" "$latest" "up-to-date"
    else
        warn "$name $current -> $latest  ($repo)"
        add_result "$name" "$category" "$current" "$latest" "update-available"
        updates_found=$((updates_found + 1))
    fi
}

# --- Check an npm package ---
check_npm() {
    local name="$1" category="$2" npm_pkg="$3" current="$4"

    local latest
    latest=$(curl -sf "https://registry.npmjs.org/$npm_pkg/latest" \
        | jq -r '.version // empty' 2>/dev/null) || true

    if [[ -z "$latest" ]]; then
        err "$name -- failed to fetch latest version from npm ($npm_pkg)"
        add_result "$name" "$category" "$current" "unknown" "error" "Failed to fetch from npm"
        return
    fi

    if [[ "$current" == "$latest" ]]; then
        ok "$name $current (up to date)"
        add_result "$name" "$category" "$current" "$latest" "up-to-date"
    else
        warn "$name $current -> $latest  (npm: $npm_pkg)"
        add_result "$name" "$category" "$current" "$latest" "update-available"
        updates_found=$((updates_found + 1))
    fi
}

# --- Check a github-commit package ---
check_github_commit() {
    local name="$1" category="$2" repo="$3" current_rev="$4"

    # Get latest commit on default branch
    local latest_rev
    latest_rev=$(curl -sf "https://api.github.com/repos/$repo/commits?per_page=1" \
        | jq -r '.[0].sha // empty' 2>/dev/null) || true

    if [[ -z "$latest_rev" ]]; then
        err "$name -- failed to fetch latest commit from $repo"
        add_result "$name" "$category" "$current_rev" "unknown" "error" "Failed to fetch commits"
        return
    fi

    if [[ "$current_rev" == "$latest_rev" ]]; then
        ok "$name ${current_rev:0:8} (up to date)"
        add_result "$name" "$category" "${current_rev:0:8}" "${latest_rev:0:8}" "up-to-date"
        return
    fi

    # Get age of pinned commit
    local pinned_date
    pinned_date=$(curl -sf "https://api.github.com/repos/$repo/commits/$current_rev" \
        | jq -r '.commit.committer.date // empty' 2>/dev/null) || true

    local age_info=""
    if [[ -n "$pinned_date" ]]; then
        local pinned_epoch now_epoch days_old
        pinned_epoch=$(date -d "$pinned_date" +%s 2>/dev/null || echo "")
        now_epoch=$(date +%s)
        if [[ -n "$pinned_epoch" ]]; then
            days_old=$(( (now_epoch - pinned_epoch) / 86400 ))
            age_info="${days_old} days old"
        fi
    fi

    # Count commits between pinned and latest
    local commits_behind=""
    local compare_json
    compare_json=$(curl -sf "https://api.github.com/repos/$repo/compare/${current_rev}...${latest_rev}" 2>/dev/null) || true
    if [[ -n "$compare_json" ]]; then
        local ahead
        ahead=$(echo "$compare_json" | jq -r '.ahead_by // empty' 2>/dev/null) || true
        if [[ -n "$ahead" ]]; then
            commits_behind="${ahead} commits behind"
        fi
    fi

    local detail=""
    [[ -n "$age_info" ]] && detail="$age_info"
    [[ -n "$commits_behind" ]] && detail="${detail:+$detail, }$commits_behind"

    warn "$name ${current_rev:0:8} -> ${latest_rev:0:8}  ($detail)"
    add_result "$name" "$category" "${current_rev:0:8}" "${latest_rev:0:8}" "update-available" "$detail"
    updates_found=$((updates_found + 1))
}

# --- Iterate all packages ---
echo "Checking all pinned packages for updates..."
echo ""

for category in $(echo "$versions_json" | jq -r 'keys[]'); do
    info "Category: $category"

    for pkg in $(echo "$versions_json" | jq -r ".[\"$category\"] | keys[]"); do
        entry=$(echo "$versions_json" | jq -r ".[\"$category\"][\"$pkg\"]")
        source=$(echo "$entry" | jq -r '.source')

        case "$source" in
            github-release)
                version=$(echo "$entry" | jq -r '.version')
                repo=$(echo "$entry" | jq -r '.repo')
                prefix=$(echo "$entry" | jq -r '.tagPrefix // ""')
                check_github_release "$pkg" "$category" "$repo" "$version" "$prefix"
                ;;
            npm)
                version=$(echo "$entry" | jq -r '.version')
                npm_pkg=$(echo "$entry" | jq -r '.npmPkg // empty')
                [[ -z "$npm_pkg" ]] && npm_pkg="$pkg"
                check_npm "$pkg" "$category" "$npm_pkg" "$version"
                ;;
            github-commit)
                repo=$(echo "$entry" | jq -r '.repo')
                rev=$(echo "$entry" | jq -r '.rev')
                check_github_commit "$pkg" "$category" "$repo" "$rev"
                ;;
            sourcehut)
                version=$(echo "$entry" | jq -r '.version')
                # SourceHut has no standard releases API; report as manual-check
                info "  $pkg $version (sourcehut -- check manually)"
                add_result "$pkg" "$category" "$version" "unknown" "manual" "SourceHut packages require manual checking"
                ;;
            *)
                err "$pkg -- unknown source type: $source"
                ;;
        esac
    done

    echo ""
done

# --- Write cache ---
echo "$results" | jq '.' > "$CACHE_FILE"
info "Results cached to $CACHE_FILE"

# --- Summary ---
echo ""
if [[ "$updates_found" -gt 0 ]]; then
    echo -e "\033[1;33m$updates_found update(s) available.\033[0m"
    echo ""
    echo "To update:"
    echo "  Single:  just update-pkg <name>"
    echo "  All:     just update-pkg --all"
else
    echo -e "\033[1;32mAll packages up to date.\033[0m"
fi
```

**Step 2: Verify it runs**

Run: `bash extras/scripts/check-pkg-updates.bash`
Expected: Iterates all 12 packages, prints status for each, writes cache file

**Step 3: Commit**

```bash
git add extras/scripts/check-pkg-updates.bash
```

Suggested: `feat(versions): rewrite update checker as data-driven from versions.nix`

---

### Task 14: Create update-pkg.bash

**Files:**

- Create: `extras/scripts/update-pkg.bash`

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Update a pinned package version in versions.nix
# Prefetches new hash and writes it to the file
# Usage: update-pkg.bash <name> | --all [--include-commits]

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSIONS_FILE="$REPO_ROOT/settings/versions.nix"
CACHE_FILE="/tmp/nixerator-pkg-status.json"

# --- Helpers ---
info()  { echo -e "\033[1;34m[update]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[update]\033[0m $*"; }
err()   { echo -e "\033[1;31m[update]\033[0m $*" >&2; }

# --- Parse args ---
target=""
include_commits=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) target="__all__"; shift ;;
        --include-commits) include_commits=true; shift ;;
        -*) err "Unknown flag: $1"; exit 1 ;;
        *) target="$1"; shift ;;
    esac
done

if [[ -z "$target" ]]; then
    err "Usage: update-pkg.bash <name> | --all [--include-commits]"
    exit 1
fi

# --- Load versions ---
versions_json=$(nix eval --json -f "$REPO_ROOT/extras/scripts/nix-to-json.nix")

# --- Find a package entry by name across all categories ---
find_pkg() {
    local name="$1"
    for category in $(echo "$versions_json" | jq -r 'keys[]'); do
        local entry
        entry=$(echo "$versions_json" | jq -r ".[\"$category\"][\"$name\"] // empty")
        if [[ -n "$entry" ]]; then
            echo "$entry"
            return 0
        fi
    done
    return 1
}

find_pkg_category() {
    local name="$1"
    for category in $(echo "$versions_json" | jq -r 'keys[]'); do
        local entry
        entry=$(echo "$versions_json" | jq -r ".[\"$category\"][\"$name\"] // empty")
        if [[ -n "$entry" ]]; then
            echo "$category"
            return 0
        fi
    done
    return 1
}

# --- Prefetch a GitHub release tarball ---
prefetch_github_release() {
    local repo="$1" version="$2" prefix="$3"
    local tag="${prefix}${version}"
    local url="https://github.com/$repo/archive/refs/tags/$tag.tar.gz"
    info "Prefetching $url..."
    local nix_hash
    nix_hash=$(nix-prefetch-url --unpack "$url" 2>/dev/null)
    nix hash convert --hash-algo sha256 --to sri "$nix_hash"
}

# --- Prefetch an npm tarball ---
prefetch_npm() {
    local npm_pkg="$1" version="$2"
    local url="https://registry.npmjs.org/$npm_pkg/-/$npm_pkg-$version.tgz"
    info "Prefetching $url..."
    local nix_hash
    nix_hash=$(nix-prefetch-url "$url" 2>/dev/null)
    nix hash convert --hash-algo sha256 --to sri "$nix_hash"
}

# --- Update version string in versions.nix ---
update_version() {
    local name="$1" old_version="$2" new_version="$3"
    info "Updating $name version: $old_version -> $new_version"
    # Use a targeted sed within the package's block
    sed -i "/$name/,/}/ s/version = \"$old_version\"/version = \"$new_version\"/" "$VERSIONS_FILE"
}

# --- Update hash in versions.nix ---
update_hash() {
    local name="$1" new_hash="$2"
    info "Updating $name hash"
    sed -i "/$name/,/}/ s|hash = \"sha256-[^\"]*\"|hash = \"$new_hash\"|" "$VERSIONS_FILE"
}

# --- Update rev in versions.nix ---
update_rev() {
    local name="$1" new_rev="$2"
    info "Updating $name rev"
    sed -i "/$name/,/}/ s|rev = \"[^\"]*\"|rev = \"$new_rev\"|" "$VERSIONS_FILE"
}

# --- Get latest version for a package ---
get_latest_github_release() {
    local repo="$1" prefix="$2"
    local tag
    tag=$(curl -sf "https://api.github.com/repos/$repo/releases/latest" \
        | jq -r '.tag_name // empty' 2>/dev/null) || true
    [[ -z "$tag" ]] && return 1
    echo "${tag#"$prefix"}"
}

get_latest_npm() {
    local npm_pkg="$1"
    curl -sf "https://registry.npmjs.org/$npm_pkg/latest" \
        | jq -r '.version // empty' 2>/dev/null
}

get_latest_github_commit() {
    local repo="$1"
    curl -sf "https://api.github.com/repos/$repo/commits?per_page=1" \
        | jq -r '.[0].sha // empty' 2>/dev/null
}

# --- Update a single package ---
update_single() {
    local name="$1"
    local entry category source

    entry=$(find_pkg "$name") || { err "Package '$name' not found in versions.nix"; exit 1; }
    category=$(find_pkg_category "$name")
    source=$(echo "$entry" | jq -r '.source')

    case "$source" in
        github-release)
            local repo prefix current_version latest_version
            repo=$(echo "$entry" | jq -r '.repo')
            prefix=$(echo "$entry" | jq -r '.tagPrefix // ""')
            current_version=$(echo "$entry" | jq -r '.version')
            latest_version=$(get_latest_github_release "$repo" "$prefix")

            if [[ -z "$latest_version" ]]; then
                err "Failed to fetch latest release for $name"
                return 1
            fi

            if [[ "$current_version" == "$latest_version" ]]; then
                ok "$name is already at $current_version"
                return 0
            fi

            info "$name: $current_version -> $latest_version"
            local new_hash
            new_hash=$(prefetch_github_release "$repo" "$latest_version" "$prefix")
            update_version "$name" "$current_version" "$latest_version"
            update_hash "$name" "$new_hash"
            ok "$name updated to $latest_version"
            ;;

        npm)
            local npm_pkg current_version latest_version
            npm_pkg=$(echo "$entry" | jq -r '.npmPkg // empty')
            [[ -z "$npm_pkg" ]] && npm_pkg="$name"
            current_version=$(echo "$entry" | jq -r '.version')
            latest_version=$(get_latest_npm "$npm_pkg")

            if [[ -z "$latest_version" ]]; then
                err "Failed to fetch latest npm version for $name"
                return 1
            fi

            if [[ "$current_version" == "$latest_version" ]]; then
                ok "$name is already at $current_version"
                return 0
            fi

            info "$name: $current_version -> $latest_version"
            local new_hash
            new_hash=$(prefetch_npm "$npm_pkg" "$latest_version")
            update_version "$name" "$current_version" "$latest_version"
            update_hash "$name" "$new_hash"

            # Check for colocated package-lock.json files that need updating
            local lockfiles
            lockfiles=$(find "$REPO_ROOT/modules" -name "package-lock.json" -path "*$name*" -o -name "package-lock.json" -path "*$(echo "$name" | tr '-' '/')*" 2>/dev/null || true)
            if [[ -n "$lockfiles" ]]; then
                while IFS= read -r lockfile; do
                    info "Updating lockfile: $lockfile"
                    sed -i "s/\"version\": \"$current_version\"/\"version\": \"$latest_version\"/g" "$lockfile"
                done <<< "$lockfiles"
                info "NOTE: npmDepsHash may need updating. Run 'just qr' -- if it fails, update npmDepsHash in versions.nix with the hash from the error output."
            fi

            ok "$name updated to $latest_version"
            ;;

        github-commit)
            if [[ "$target" != "__all__" ]] || [[ "$include_commits" == "true" ]]; then
                local repo current_rev latest_rev
                repo=$(echo "$entry" | jq -r '.repo')
                current_rev=$(echo "$entry" | jq -r '.rev')
                latest_rev=$(get_latest_github_commit "$repo")

                if [[ -z "$latest_rev" ]]; then
                    err "Failed to fetch latest commit for $name"
                    return 1
                fi

                if [[ "$current_rev" == "$latest_rev" ]]; then
                    ok "$name is already at ${current_rev:0:8}"
                    return 0
                fi

                info "$name: ${current_rev:0:8} -> ${latest_rev:0:8}"
                # Prefetch the new commit
                local prefetch_output new_hash
                prefetch_output=$(nix-prefetch-git "https://github.com/$repo" --rev "$latest_rev" --quiet 2>/dev/null)
                new_hash=$(echo "$prefetch_output" | jq -r '.hash')
                update_rev "$name" "$latest_rev"
                update_hash "$name" "$new_hash"

                # If there's a vendorHash, warn that it may need updating
                local has_vendor
                has_vendor=$(echo "$entry" | jq -r '.vendorHash // empty')
                if [[ -n "$has_vendor" ]]; then
                    info "NOTE: $name has a vendorHash that may need updating. Run 'just qr' -- if it fails, update vendorHash in versions.nix with the hash from the error output."
                fi

                ok "$name updated to ${latest_rev:0:8}"
            else
                info "Skipping commit-pinned package $name (use --include-commits to update)"
            fi
            ;;

        sourcehut)
            info "Skipping $name (SourceHut -- update manually)"
            ;;

        *)
            err "Unknown source type for $name: $source"
            ;;
    esac
}

# --- Main ---
if [[ "$target" == "__all__" ]]; then
    info "Updating all packages..."
    echo ""
    for category in $(echo "$versions_json" | jq -r 'keys[]'); do
        for pkg in $(echo "$versions_json" | jq -r ".[\"$category\"] | keys[]"); do
            update_single "$pkg" || true
        done
    done
else
    update_single "$target"
fi

echo ""
ok "Done. Run 'just qr' to rebuild and verify."
```

**Step 2: Make it executable**

Run: `chmod +x extras/scripts/update-pkg.bash`

**Step 3: Test with a dry read**

Run: `bash extras/scripts/update-pkg.bash amber`
Expected: Either "already at X" or prefetches and updates versions.nix

**Step 4: Commit**

```bash
git add extras/scripts/update-pkg.bash
```

Suggested: `feat(versions): add update-pkg script for automated prefetch and update`

---

### Task 15: Update justfile and setup.just with new recipes

**Files:**

- Modify: `justfile` (add cache report to non-quiet rebuild recipes)
- Modify: `extras/setup.just` (update recipes to point to new scripts, remove update-gsd)

**Step 1: Add cache report to the `rebuild` recipe in justfile**

At the end of the success path in the `rebuild` recipe (after "Rebuild succeeded"), add:

```bash
        # Show cached package update report if recent
        if [[ -f /tmp/nixerator-pkg-status.json ]]; then
            age=$(( $(date +%s) - $(stat -c %Y /tmp/nixerator-pkg-status.json) ))
            if [[ "$age" -lt 86400 ]]; then
                updates=$(jq '[.[] | select(.status == "update-available")] | length' /tmp/nixerator-pkg-status.json)
                if [[ "$updates" -gt 0 ]]; then
                    echo ""
                    gum style --foreground 220 "$updates package update(s) available (run 'just setup::check-updates' for details)"
                fi
            fi
        fi
```

Add this block inside both success paths of the `rebuild` recipe (after the "Rebuild succeeded" and after the warnings check).

**Step 2: Do the same for the `upgrade` recipe**

Add the same block at the end of the `upgrade` recipe's success path.

**Step 3: Update setup.just**

Replace the version updates section:

```just
# === Version Updates ===

# Check all pinned packages for new releases (caches results)
[group('update')]
check-updates:
    @bash extras/scripts/check-pkg-updates.bash

# Update a specific package (prefetch + write to versions.nix)
[group('update')]
update-pkg *args:
    @bash extras/scripts/update-pkg.bash {{args}}
```

Remove the `update-gsd` recipe entirely.

**Step 4: Commit**

```bash
git add justfile extras/setup.just
```

Suggested: `feat(versions): add update recipes and post-rebuild report to justfile`

---

### Task 16: Delete the old update-gsd.bash script

**Files:**

- Delete: `modules/apps/cli/claude-code/cfg/scripts/update-gsd.bash`

**Step 1: Remove the file**

Run: `rm modules/apps/cli/claude-code/cfg/scripts/update-gsd.bash`

**Step 2: Check for references**

Run: `grep -r "update-gsd" . --include="*.nix" --include="*.just" --include="*.bash" --include="*.md"`

Update or remove any remaining references found (likely in setup.just which was already updated, and possibly in docs).

**Step 3: Commit**

```bash
git rm modules/apps/cli/claude-code/cfg/scripts/update-gsd.bash
```

Suggested: `chore(gsd): remove update-gsd.bash, replaced by update-pkg`

---

### Task 17: Update documentation

**Files:**

- Modify: `extras/docs/local-packages.md`
- Modify: `extras/docs/commands.md`

**Step 1: Rewrite local-packages.md**

````markdown
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
2. Include all required fields: `version`/`rev`, `source`, `repo`, `hash`, and any optional fields (`tagPrefix`, `npmPkg`, `npmDepsHash`, `vendorHash`, `hashes`)
3. In your build file, add `versions` to the function arguments and reference fields via `versions.<category>.<name>`

## Updating Packages

```bash
just setup::check-updates          # check all packages, cache results
just setup::update-pkg <name>      # prefetch + write new version for one package
just setup::update-pkg --all       # update all release-tracked packages
just setup::update-pkg --all --include-commits   # also update commit-pinned packages
just qr                            # rebuild to verify
```
````

````

**Step 2: Add new recipes to commands.md**

In `extras/docs/commands.md`, find the section near the end (or add a new section) for version management. Add after the existing content, before the Claude Code section:

```markdown
## Version Management

All pinned package versions are centralized in `settings/versions.nix`.

- `just setup::check-updates` -- check all packages for updates (caches to `/tmp/nixerator-pkg-status.json`)
- `just setup::update-pkg <name>` -- prefetch and write new version+hash for one package
- `just setup::update-pkg --all` -- update all release-tracked packages
- `just setup::update-pkg --all --include-commits` -- also update commit-pinned packages

Non-quiet rebuild recipes show a summary of available updates after a successful rebuild (if cached results exist and are less than 24 hours old).
````

**Step 3: Commit**

```bash
git add extras/docs/local-packages.md extras/docs/commands.md
```

Suggested: `docs(versions): update local-packages and commands docs for centralized version management`

---

### Task 18: Final verification rebuild

**Step 1: Run a full quiet rebuild**

Run: `just qr`
Expected: Rebuild succeeds with all build files reading from versions.nix

**Step 2: Run the update checker**

Run: `just setup::check-updates`
Expected: All 12 packages checked, results cached

**Step 3: Verify the cache report in rebuild**

Run: `just rebuild`
Expected: After rebuild succeeds, see "N package update(s) available" if any exist

---

Plan complete and saved to `docs/plans/2026-03-07-centralized-version-management.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
