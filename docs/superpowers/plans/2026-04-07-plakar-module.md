# Plakar Backup Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a declarative NixOS module for the Plakar backup tool with support for multiple named stores (Backblaze B2, Google Drive via rclone) and scheduled backup jobs.

**Architecture:** A CLI app module at `modules/apps/cli/plakar/` with a local `buildGoModule` derivation in `build/`. The module generates YAML config files for Plakar stores and scheduler tasks, imports them via an activation script, and runs Plakar's built-in scheduler as a long-running systemd service. Secrets flow from `secrets/secrets.json` through host config wiring (same pattern as restic).

**Tech Stack:** Nix (NixOS module system), Go (`buildGoModule`), systemd, YAML generation, Fish shell (helper CLI)

**Spec:** `docs/superpowers/specs/2026-04-07-plakar-module-design.md`

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `modules/apps/cli/plakar/build/default.nix` | `buildGoModule` derivation for plakar binary |
| Create | `modules/apps/cli/plakar/default.nix` | Module options, YAML generation, activation script, systemd service, plakar-mgr CLI |
| Modify | `settings/versions.nix` | Add plakar version entry with hash + vendorHash |
| Modify | `modules/suites/core/default.nix:33` | Enable `plakar` in core suite |
| Modify | `secrets/secrets.json` | Add `plakar` key with B2 creds and passphrase (user handles this) |

---

### Task 1: Add Plakar Version Entry

**Files:**
- Modify: `settings/versions.nix` (add entry in `cli` section)

- [ ] **Step 1: Get the latest stable Plakar release tag and source hash**

Run:
```bash
# Check latest release
nix-prefetch-url --unpack --type sha256 https://github.com/PlakarKorp/plakar/archive/refs/tags/v1.0.6.tar.gz 2>&1 | tail -1
```

Then convert to SRI hash:
```bash
nix hash to-sri --type sha256 <HASH_FROM_ABOVE>
```

Expected: An SRI hash like `sha256-XXXX...`

- [ ] **Step 2: Add plakar entry to versions.nix**

Add the following entry to the `cli` attrset in `settings/versions.nix`, alphabetically (after `meetsum`, before the next entry):

```nix
    plakar = {
      source = "github-release";
      repo = "PlakarKorp/plakar";
      version = "1.0.6";
      tagPrefix = "v";
      hash = "<SRI_HASH_FROM_STEP_1>";
      vendorHash = null;  # Will be replaced after first build attempt
    };
```

- [ ] **Step 3: Commit**

```bash
git add settings/versions.nix
git commit -m "feat(plakar): add version entry to versions.nix"
```

---

### Task 2: Create the buildGoModule Derivation

**Files:**
- Create: `modules/apps/cli/plakar/build/default.nix`

**Reference:** `modules/apps/cli/jwtx/build/default.nix` for the exact pattern.

- [ ] **Step 1: Create the build directory**

```bash
mkdir -p /home/dustin/git/nixerator/modules/apps/cli/plakar/build
```

- [ ] **Step 2: Write the derivation**

Create `modules/apps/cli/plakar/build/default.nix`:

```nix
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versions,
}:

let
  v = versions.cli.plakar;
in
buildGoModule rec {
  pname = "plakar";
  inherit (v) version;

  src = fetchFromGitHub {
    owner = "PlakarKorp";
    repo = "plakar";
    rev = "v${version}";
    inherit (v) hash;
  };

  inherit (v) vendorHash;

  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Plakar backup tool with deduplication and encryption";
    homepage = "https://github.com/PlakarKorp/plakar";
    license = licenses.isc;
    maintainers = [ ];
    mainProgram = "plakar";
  };
}
```

- [ ] **Step 3: Test the build to get the correct vendorHash**

```bash
nix-build -E 'let pkgs = import <nixpkgs> {}; versions = import /home/dustin/git/nixerator/settings/versions.nix; in pkgs.callPackage /home/dustin/git/nixerator/modules/apps/cli/plakar/build { inherit versions; }'
```

This will fail with a hash mismatch for `vendorHash`. Copy the correct hash from the error output and update `settings/versions.nix`:

```nix
      vendorHash = "<CORRECT_VENDOR_HASH_FROM_ERROR>";
```

- [ ] **Step 4: Re-run the build to verify it succeeds**

```bash
nix-build -E 'let pkgs = import <nixpkgs> {}; versions = import /home/dustin/git/nixerator/settings/versions.nix; in pkgs.callPackage /home/dustin/git/nixerator/modules/apps/cli/plakar/build { inherit versions; }'
```

Expected: Build succeeds, `result/bin/plakar` exists.

- [ ] **Step 5: Verify the binary works**

```bash
./result/bin/plakar version
```

Expected: Version output showing `1.0.6` or similar.

- [ ] **Step 6: Commit**

```bash
git add modules/apps/cli/plakar/build/default.nix settings/versions.nix
git commit -m "feat(plakar): add buildGoModule derivation"
```

---

### Task 3: Create the Module with Options

**Files:**
- Create: `modules/apps/cli/plakar/default.nix`

**Reference:** `modules/apps/cli/jwtx/default.nix` (simple pattern), `modules/server/restic/default.nix` (options + systemd + helper CLI pattern).

- [ ] **Step 1: Write the module with options, YAML generation, activation script, systemd service, and plakar-mgr helper**

Create `modules/apps/cli/plakar/default.nix`:

```nix
{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.plakar;
  plakar = pkgs.callPackage ./build { inherit versions; };

  # Generate stores YAML for S3/B2-type stores
  s3Stores = lib.filterAttrs (_: s: s.type == "s3") cfg.stores;
  storesYaml = pkgs.writeText "plakar-stores.yaml" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: store: ''
          ${name}:
            location: ${store.location}
            access_key: ${store.accessKey}
            secret_access_key: ${store.secretAccessKey}
            use_tls: ${lib.boolToString store.useTls}
            passphrase: ${store.passphrase}
        ''
      ) s3Stores
    )
  );

  # Collect rclone-type stores for import commands
  rcloneStores = lib.filterAttrs (_: s: s.type == "rclone") cfg.stores;

  # Generate scheduler YAML
  schedulerYaml = pkgs.writeText "plakar-scheduler.yaml" (
    ''
      agent:
        tasks:
    ''
    + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: job: ''
            - name: ${name}
              repository: "${job.store}"
              backup:
                path: ${lib.concatStringsSep "," job.paths}
                interval: ${job.interval}
                check: ${lib.boolToString job.check}
        ''
      ) cfg.jobs
    )
  );

  # Activation script to import stores and initialize repos
  activationScript = pkgs.writeShellScript "plakar-activate" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [ plakar pkgs.rclone ]}:$PATH"

    mkdir -p /etc/plakar

    # Import S3/B2 stores
    ${lib.optionalString (s3Stores != { }) ''
      plakar -config /etc/plakar store import -config ${storesYaml}
    ''}

    # Import rclone stores
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: store: ''
          rclone config show | plakar -config /etc/plakar store import -rclone ${store.rcloneRemote}
        ''
      ) rcloneStores
    )}

    # Initialize stores (skip if already initialized)
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: _: ''
          plakar -config /etc/plakar at "@${name}" create 2>/dev/null || true
        ''
      ) cfg.stores
    )}
  '';

  # plakar-mgr helper CLI (Fish script, matching backup-mgr pattern)
  plakar-mgr = ''
    #!/run/current-system/sw/bin/env fish

    set -x PLAKAR_BIN "${plakar}/bin/plakar"
    set -x PLAKAR_CONFIG "/etc/plakar"

    function init_stores
      $PLAKAR_BIN -config $PLAKAR_CONFIG store import -config ${storesYaml}
      ${lib.concatStringsSep "\n    " (
        lib.mapAttrsToList (name: _: ''
          $PLAKAR_BIN -config $PLAKAR_CONFIG at "@${name}" create 2>/dev/null; or true
        '') cfg.stores
      )}
      echo "All stores initialized."
    end

    function list_snapshots
      ${lib.concatStringsSep "\n    " (
        lib.mapAttrsToList (name: _: ''
          echo "--- Store: ${name} ---"
          $PLAKAR_BIN -config $PLAKAR_CONFIG at "@${name}" ls 2>/dev/null; or echo "(no snapshots or store not initialized)"
        '') cfg.stores
      )}
    end

    function check_store
      if test (count $argv) -lt 1
        echo "Usage: plakar-mgr -check <store-name>"
        return 1
      end
      $PLAKAR_BIN -config $PLAKAR_CONFIG at "@$argv[1]" check
    end

    function restore_snapshot
      if test (count $argv) -lt 2
        echo "Usage: plakar-mgr -restore <store-name> <snapshot-id>"
        return 1
      end
      $PLAKAR_BIN -config $PLAKAR_CONFIG at "@$argv[1]" restore $argv[2]
    end

    function check_status
      systemctl status plakar-scheduler.service
    end

    function check_logs
      journalctl -u plakar-scheduler.service
    end

    function show_help
      echo "Usage: plakar-mgr [OPTION]"
      echo "Options:"
      echo "  -help               Show this help message"
      echo "  -init               Initialize all configured stores"
      echo "  -list               List snapshots across all stores"
      echo "  -status             Show systemd service status"
      echo "  -logs               Show service journal logs"
      echo "  -restore <store> <snapshot>  Restore a specific snapshot"
      echo "  -check <store>      Run integrity check on a store"
    end

    if test (count $argv) -gt 0 -a "$argv[1]" = "-init"
      init_stores
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-list"
      list_snapshots
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-restore"
      restore_snapshot $argv[2..]
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-check"
      check_store $argv[2..]
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-status"
      check_status
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-logs"
      check_logs
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-help"
      show_help
    else
      show_help
    end
  '';

in
{
  options = {
    apps.cli.plakar = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Plakar backup tool with declarative store and job configuration.";
      };

      stores = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              type = lib.mkOption {
                type = lib.types.enum [
                  "s3"
                  "rclone"
                ];
                description = "Store backend type.";
              };

              location = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "S3-compatible endpoint URL (e.g., s3://s3.us-west-004.backblazeb2.com/mybucket/plakar).";
              };

              accessKey = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "S3/B2 access key ID.";
              };

              secretAccessKey = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "S3/B2 secret access key.";
              };

              useTls = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Use TLS for S3 connections.";
              };

              rcloneRemote = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Name of the rclone remote to import (e.g., 'mydrive'). Requires rclone to be configured.";
              };

              passphrase = lib.mkOption {
                type = lib.types.str;
                description = "Kloset store encryption passphrase.";
              };
            };
          }
        );
        default = { };
        description = "Named Plakar stores (backup destinations).";
      };

      jobs = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              store = lib.mkOption {
                type = lib.types.str;
                description = "Store name to back up to (references a key in stores, prefixed with @).";
              };

              paths = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = "Filesystem paths to back up.";
              };

              interval = lib.mkOption {
                type = lib.types.str;
                default = "24h";
                description = "Backup interval (Go duration: 1h, 24h, 168h, etc.).";
              };

              check = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Run integrity check after each backup.";
              };
            };
          }
        );
        default = { };
        description = "Named backup jobs.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      plakar
      pkgs.rclone
      (pkgs.writeScriptBin "plakar-mgr" plakar-mgr)
    ];

    system.activationScripts.plakar-setup = lib.stringAfter [ "etc" ] ''
      ${activationScript}
    '';

    systemd.services.plakar-scheduler = lib.mkIf (cfg.jobs != { }) {
      description = "Plakar backup scheduler";
      after = [
        "network-online.target"
        "multi-user.target"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${plakar}/bin/plakar -config /etc/plakar scheduler start -tasks ${schedulerYaml} -foreground";
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
  };
}
```

- [ ] **Step 2: Syntax-check the module**

```bash
nix-instantiate --parse /home/dustin/git/nixerator/modules/apps/cli/plakar/default.nix
```

Expected: Parsed output with no errors.

- [ ] **Step 3: Commit**

```bash
git add modules/apps/cli/plakar/default.nix
git commit -m "feat(plakar): add module with stores, jobs, systemd scheduler, and plakar-mgr"
```

---

### Task 4: Enable Plakar in Core Suite

**Files:**
- Modify: `modules/suites/core/default.nix:33`

- [ ] **Step 1: Add plakar to the core suite**

In `modules/suites/core/default.nix`, add `plakar.enable = true;` inside the `apps.cli` block, after the `restic.enable = true;` line (line 33):

```nix
      apps = {
        cli = {
          tailscale.enable = true;
          cpx.enable = true;
          gws.enable = true;
          restic.enable = true;
          plakar.enable = true;
        };
        gui.web-app-hub.enable = true;
      };
```

- [ ] **Step 2: Commit**

```bash
git add modules/suites/core/default.nix
git commit -m "feat(plakar): enable in core suite"
```

---

### Task 5: Add Secrets and Test Full Build

**Files:**
- Modify: `secrets/secrets.json` (user handles decryption/editing)

- [ ] **Step 1: Document required secrets structure**

The user needs to add this to `secrets/secrets.json` (after `git-crypt unlock`):

```json
{
  "plakar": {
    "b2_account_id": "<Backblaze B2 keyID>",
    "b2_account_key": "<Backblaze B2 applicationKey>",
    "passphrase": "<chosen Kloset encryption passphrase>"
  }
}
```

- [ ] **Step 2: Wire up secrets in a host config**

The user creates host-level configuration (e.g., in `hosts/donkeykong/modules.nix` or wherever plakar should run) that references the secrets. Example:

```nix
apps.cli.plakar = {
  enable = true;

  stores = {
    b2-backup = {
      type = "s3";
      location = "s3://s3.us-west-004.backblazeb2.com/mybucket/plakar";
      accessKey = secrets.plakar.b2_account_id;
      secretAccessKey = secrets.plakar.b2_account_key;
      passphrase = secrets.plakar.passphrase;
    };
    # gdrive-backup can be added after running `rclone config` once
    # gdrive-backup = {
    #   type = "rclone";
    #   rcloneRemote = "gdrive";
    #   passphrase = secrets.plakar.passphrase;
    # };
  };

  jobs = {
    home-to-b2 = {
      store = "@b2-backup";
      paths = [ "/home" ];
      interval = "24h";
      check = true;
    };
  };
};
```

- [ ] **Step 3: Test a full NixOS build**

```bash
just quiet-rebuild
```

If the build fails, spawn a Nix subagent to read `/tmp/nixerator-rebuild.log`, diagnose, and fix.

Expected: Successful build with `plakar` and `plakar-mgr` available in PATH.

- [ ] **Step 4: Verify the binary is available**

```bash
plakar version
plakar-mgr -help
```

Expected: Both commands produce output.

- [ ] **Step 5: Verify systemd service is registered**

```bash
systemctl status plakar-scheduler.service
```

Expected: Service is loaded (may not be active until stores are initialized).

- [ ] **Step 6: Commit all remaining changes**

```bash
git add -A
git commit -m "feat(plakar): wire up secrets and host configuration"
```

---

### Task 6: Google Drive Setup (Post-Deploy)

This task is manual and only needed when the user wants to add Google Drive as a backup destination.

- [ ] **Step 1: Configure rclone for Google Drive**

```bash
rclone config
```

Follow the interactive prompts:
1. `n` (new remote)
2. Name: `gdrive`
3. Storage: `drive` (Google Drive)
4. Leave client_id and client_secret blank (use rclone defaults)
5. Scope: `1` (full access)
6. Authenticate via browser when prompted

- [ ] **Step 2: Verify rclone config works**

```bash
rclone lsd gdrive:
```

Expected: Lists folders in Google Drive root.

- [ ] **Step 3: Add gdrive store to host config**

Uncomment (or add) the `gdrive-backup` store and a corresponding job in the host config from Task 5 Step 2.

- [ ] **Step 4: Rebuild to import the rclone store**

```bash
just quiet-rebuild
```

- [ ] **Step 5: Verify both stores are working**

```bash
plakar-mgr -list
```

Expected: Shows snapshot listings (or "no snapshots") for both stores.
