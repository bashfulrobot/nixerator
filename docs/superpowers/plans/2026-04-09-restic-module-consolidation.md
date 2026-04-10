# Restic Module Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge `server.restic` backup functionality into `apps.cli.restic`, drop autorestic/backrest, enable on qbert with plakar's backup paths, disable plakar.

**Architecture:** The existing `server.restic` module has all the backup logic (backup-mgr script, systemd timer, retention policies). The `apps.cli.restic` module just installs packages. We merge the backup config into `apps.cli.restic` with an optional `backup` sub-option, so hosts can install restic without configuring backups, or configure backups declaratively. Each host provides its own backup settings via `modules.nix`.

**Tech Stack:** NixOS modules, systemd timers, restic, Fish shell, B2/S3

---

## File Map

- **Modify:** `modules/apps/cli/restic/default.nix` — merge backup-mgr, systemd timer, backup options from server.restic; drop autorestic and backrest packages
- **Delete:** `modules/server/restic/default.nix` — superseded by merged module
- **Modify:** `hosts/srv/modules.nix` — switch from `server.restic.*` to `apps.cli.restic.backup.*`; remove explicit import of `../../modules/server/restic`
- **Modify:** `hosts/qbert/modules.nix` — add `apps.cli.restic.backup.*` config with plakar's paths; remove plakar config
- **Modify:** `modules/suites/core/default.nix` — remove `plakar.enable = true` line

---

### Task 1: Merge backup functionality into apps.cli.restic

**Files:**
- Modify: `modules/apps/cli/restic/default.nix`

- [ ] **Step 1: Read the current files**

Read both `modules/apps/cli/restic/default.nix` and `modules/server/restic/default.nix` to understand the full picture before editing.

- [ ] **Step 2: Write the merged module**

Replace `modules/apps/cli/restic/default.nix` with the merged module. Key design:
- `apps.cli.restic.enable` — installs restic (just the binary, no autorestic/backrest)
- `apps.cli.restic.backup.*` — optional backup configuration (repository, paths, schedule, retention, secrets)
- `backup-mgr` Fish script — carried over from server.restic with the same commands
- systemd timer + service — carried over from server.restic

```nix
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.apps.cli.restic;
  bcfg = cfg.backup;

  backup-mgr = ''
    #!/run/current-system/sw/bin/env fish

    set -x RESTIC_BIN "/run/current-system/sw/bin/restic"

    set -x RESTIC_HOST (hostname)
    set -x RESTIC_REPOSITORY "${bcfg.repository}"
    set -x AWS_ACCESS_KEY_ID "${bcfg.awsAccessKeyId}"
    set -x AWS_SECRET_ACCESS_KEY "${bcfg.awsSecretAccessKey}"
    set -x AWS_DEFAULT_REGION "${bcfg.awsRegion}"
    set -x RESTIC_PASSWORD "${bcfg.password}"

    function init_repo
      $RESTIC_BIN -r $RESTIC_REPOSITORY init
    end

    function restore_backup
      $RESTIC_BIN -r $RESTIC_REPOSITORY restore latest --target ${bcfg.restorePath}
    end

    function list_backups
      $RESTIC_BIN -r $RESTIC_REPOSITORY snapshots
    end

    function run_backup
      $RESTIC_BIN -r $RESTIC_REPOSITORY backup ${lib.concatStringsSep " " bcfg.backupPaths}
      $RESTIC_BIN -r $RESTIC_REPOSITORY forget --prune --host $RESTIC_HOST --keep-daily ${toString bcfg.keepDaily} --keep-weekly ${toString bcfg.keepWeekly} --keep-monthly ${toString bcfg.keepMonthly} --keep-yearly ${toString bcfg.keepYearly}
    end

    function check_status
      systemctl status backup-mgr.timer
      systemctl status backup-mgr.service
    end

    function check_service_logs
      journalctl -u backup-mgr.service
    end

    function check_timer_logs
      journalctl -u backup-mgr.timer
    end

    function check_logs
      check_service_logs
      check_timer_logs
    end

    function show_help
      echo "Usage: backup-mgr [OPTION]"
      echo "Options:"
      echo "  -help           Show this help message"
      echo "  -init           Initialize the repository"
      echo "  -backup         Run a manual backup now"
      echo "  -list           List all snapshots"
      echo "  -restore        Restore the latest backup"
      echo "  -status         Check systemd timer and service status"
      echo "  -logs           Show all logs (service + timer)"
      echo "  -service-logs   Show service logs only"
      echo "  -timer-logs     Show timer logs only"
    end

    if test (count $argv) -gt 0 -a "$argv[1]" = "-init"
      init_repo
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-backup"
      run_backup
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-list"
      list_backups
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-restore"
      restore_backup
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-status"
      check_status
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-logs"
      check_logs
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-timer-logs"
      check_timer_logs
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-service-logs"
      check_service_logs
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-help"
      show_help
    else
      show_help
    end
  '';

in
{
  options = {
    apps.cli.restic = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable restic backup tool.";
      };

      backup = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable scheduled restic backups with backup-mgr.";
        };

        repository = lib.mkOption {
          type = lib.types.str;
          description = "Restic repository URL (e.g., s3:s3.us-west-000.backblazeb2.com/bucket-name).";
        };

        password = lib.mkOption {
          type = lib.types.str;
          description = "Restic repository password.";
        };

        awsAccessKeyId = lib.mkOption {
          type = lib.types.str;
          description = "AWS/B2 access key ID.";
        };

        awsSecretAccessKey = lib.mkOption {
          type = lib.types.str;
          description = "AWS/B2 secret access key.";
        };

        awsRegion = lib.mkOption {
          type = lib.types.str;
          description = "AWS/B2 region.";
        };

        backupPaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "Paths to back up.";
        };

        restorePath = lib.mkOption {
          type = lib.types.str;
          default = "/tmp/restic-restore";
          description = "Path where backups will be restored.";
        };

        schedule = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 03:00:00";
          description = "Systemd timer OnCalendar schedule for backups.";
        };

        keepDaily = lib.mkOption {
          type = lib.types.int;
          default = 7;
          description = "Number of daily snapshots to keep.";
        };

        keepWeekly = lib.mkOption {
          type = lib.types.int;
          default = 4;
          description = "Number of weekly snapshots to keep.";
        };

        keepMonthly = lib.mkOption {
          type = lib.types.int;
          default = 12;
          description = "Number of monthly snapshots to keep.";
        };

        keepYearly = lib.mkOption {
          type = lib.types.int;
          default = 2;
          description = "Number of yearly snapshots to keep.";
        };
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        pkgs.restic
      ];
    })

    (lib.mkIf (cfg.enable && bcfg.enable) {
      environment.systemPackages = [
        (pkgs.writeScriptBin "backup-mgr" backup-mgr)
      ];

      systemd = {
        timers.backup-mgr = {
          description = "backup-mgr timer";
          enable = true;
          wantedBy = [ "timers.target" ];
          partOf = [ "backup-mgr.service" ];
          timerConfig = {
            Persistent = "true";
            OnCalendar = bcfg.schedule;
          };
        };

        services.backup-mgr = {
          description = "Backup with restic";
          enable = true;
          serviceConfig = {
            Type = "simple";
            ExecStart = "/run/current-system/sw/bin/fish /run/current-system/sw/bin/backup-mgr";
          };
          wantedBy = [ "multi-user.target" ];
        };
      };
    })
  ];
}
```

- [ ] **Step 3: Verify the module evaluates**

Run: `nix eval .#nixosConfigurations.qbert.config.apps.cli.restic.enable --json 2>&1 | head -5`

This should return `true` (since `suites.core` enables `restic.enable`).

- [ ] **Step 4: Commit**

```
git add modules/apps/cli/restic/default.nix
git commit -S -m "refactor(restic): ♻️ merge backup functionality into apps.cli.restic"
```

---

### Task 2: Delete the old server.restic module

**Files:**
- Delete: `modules/server/restic/default.nix`

- [ ] **Step 1: Remove the old module**

```bash
rm modules/server/restic/default.nix
rmdir modules/server/restic
```

- [ ] **Step 2: Commit**

```
git add -A modules/server/restic
git commit -S -m "chore(restic): 🔧 remove superseded server.restic module"
```

---

### Task 3: Update srv to use new namespace

**Files:**
- Modify: `hosts/srv/modules.nix`

- [ ] **Step 1: Read the current srv config**

Read `hosts/srv/modules.nix` to see the current `server.restic` config block and the explicit import.

- [ ] **Step 2: Update srv/modules.nix**

Two changes:
1. Remove `../../modules/server/restic` from the imports list
2. Replace `server.restic.*` with `apps.cli.restic.backup.*`

The `server.restic.enable = true` becomes `apps.cli.restic.backup.enable = true`. Note: `apps.cli.restic.enable` is already set via `suites.core` on workstations, but srv doesn't use suites — it manually imports modules. So srv needs an explicit `apps.cli.restic.enable = true` AND the backup import path `../../modules/apps/cli/restic`.

Change the imports to replace `../../modules/server/restic` with `../../modules/apps/cli/restic`, and change the config block:

```nix
# In imports list: replace ../../modules/server/restic with:
../../modules/apps/cli/restic

# Replace the server.restic block with:
apps.cli.restic = {
  enable = true;
  backup = {
    enable = true;
    repository = secrets.restic.srv.restic_repository;
    password = secrets.restic.srv.restic_password;
    awsAccessKeyId = secrets.restic.srv.b2_account_id;
    awsSecretAccessKey = secrets.restic.srv.b2_account_key;
    awsRegion = secrets.restic.srv.region;
    backupPaths = [ "/srv/nfs" ];
    restorePath = "/srv/nfs/restores";
    schedule = "*-*-* 03:00:00";
    keepDaily = 7;
    keepWeekly = 4;
    keepMonthly = 12;
    keepYearly = 2;
  };
};
```

- [ ] **Step 3: Commit**

```
git add hosts/srv/modules.nix
git commit -S -m "refactor(restic): ♻️ migrate srv to apps.cli.restic namespace"
```

---

### Task 4: Remove all plakar code

**Files:**
- Delete: `modules/apps/cli/plakar/` (entire directory)
- Modify: `modules/suites/core/default.nix`
- Modify: `settings/versions.nix`

- [ ] **Step 1: Delete the plakar module directory**

```bash
rm -rf modules/apps/cli/plakar
```

- [ ] **Step 2: Remove plakar.enable from core suite**

In `modules/suites/core/default.nix`, remove the line `plakar.enable = true;` from the `apps.cli` block (line 34).

- [ ] **Step 3: Remove plakar version entry**

In `settings/versions.nix`, remove the `plakar` block (starts at line 35).

- [ ] **Step 4: Commit**

```
git add -A modules/apps/cli/plakar modules/suites/core/default.nix settings/versions.nix
git commit -S -m "chore(plakar): 🔧 remove plakar module, build, and version entry"
```

---

### Task 5: Enable restic backup on qbert and donkeykong

**Files:**
- Modify: `hosts/qbert/modules.nix`
- Modify: `hosts/donkeykong/modules.nix`

- [ ] **Step 1: Read current host configs**

Read `hosts/qbert/modules.nix` and `hosts/donkeykong/modules.nix`.

- [ ] **Step 2: Update qbert/modules.nix**

Remove the entire `apps.cli.plakar` block. Add restic backup config using shared workstation secrets. Also update the function arg from `{ secrets, ... }:` to include secrets if not already present.

```nix
apps.cli.restic.backup = {
  enable = true;
  repository = secrets.restic.workstation.restic_repository;
  password = secrets.restic.workstation.restic_password;
  awsAccessKeyId = secrets.restic.workstation.b2_account_id;
  awsSecretAccessKey = secrets.restic.workstation.b2_account_key;
  awsRegion = secrets.restic.workstation.region;
  backupPaths = [
    "/home/dustin/Desktop"
    "/home/dustin/dev"
    "/home/dustin/Documents"
    "/home/dustin/Downloads"
    "/home/dustin/git"
    "/home/dustin/Music"
    "/home/dustin/Pictures"
    "/home/dustin/Videos"
    "/home/dustin/.kube"
    "/home/dustin/.talos"
    "/home/dustin/.config/upsight"
    "/home/dustin/.local/share/upsight"
  ];
  restorePath = "/tmp/restic-restore";
  schedule = "*-*-* 03:00:00";
  keepDaily = 7;
  keepWeekly = 4;
  keepMonthly = 12;
  keepYearly = 2;
};
```

- [ ] **Step 3: Update donkeykong/modules.nix**

Add `secrets` to the function args (currently `_:`) and add the same restic backup config:

Change `_:` to `{ secrets, ... }:` and add the same `apps.cli.restic.backup` block as qbert.

- [ ] **Step 4: Commit**

```
git add hosts/qbert/modules.nix hosts/donkeykong/modules.nix
git commit -S -m "feat(restic): ✨ enable restic backup on qbert and donkeykong"
```

---

### Task 6: Stop plakar service and rebuild

- [ ] **Step 1: Rebuild**

Run: `just qr`

If rebuild fails, spawn a Nix subagent to read `/tmp/nixerator-rebuild.log` and diagnose.

- [ ] **Step 2: Verify backup-mgr is available**

Run: `backup-mgr -help`

Expected output should show the help menu with -init, -backup, -list, -restore, -status, -logs options.

- [ ] **Step 3: Verify systemd timer is active**

Run: `systemctl status backup-mgr.timer`

Expected: timer should be loaded and active, with the next trigger time shown.

- [ ] **Step 4: Verify plakar scheduler is gone**

Run: `systemctl status plakar-scheduler.service 2>&1`

Expected: service should not be found (it was removed from the config).

---

## Pre-requisites (user action needed before Task 5)

1. **B2 bucket:** `ws-bups` (already exists, shared across workstations)
2. **Add secrets** — add `restic.qbert` entries to `secrets/secrets.json`:
   - `restic_repository`: `s3:s3.us-west-000.backblazeb2.com/ws-bups` (restic format — `s3:` not `s3://`)
   - `restic_password`: a strong encryption password
   - `b2_account_id`: B2 application key ID
   - `b2_account_key`: B2 application key
   - `region`: `us-west-000`
3. **srv keeps its own bucket** — only the namespace changes (`server.restic` → `apps.cli.restic.backup`)
4. **Initialize restic repo** — after rebuild, run `sudo backup-mgr -init` to create the repository in the bucket
5. **Test manual backup** — run `sudo backup-mgr -backup` to verify everything works
