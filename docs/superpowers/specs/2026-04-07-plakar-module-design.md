# Plakar Backup Module Design

## Overview

A NixOS module that provides the Plakar backup tool with declarative configuration, supporting multiple named stores (Backblaze B2, Google Drive via rclone) and scheduled backup jobs via systemd.

## Module Location

`modules/apps/cli/plakar/` with:
- `default.nix` -- module definition (options, config, systemd units)
- `build/default.nix` -- `buildGoModule` derivation (plakar is not in nixpkgs)

Enabled via `apps.cli.plakar.enable = true` in the core suite (`modules/suites/core/default.nix`).

## Package Derivation

Plakar is a Go project. The `build/default.nix` uses `buildGoModule` to build from source:
- Source: `github.com/PlakarKorp/plakar` (pinned to v1.0.6 or latest stable tag)
- Binary: `plakar`
- Verify with: `plakar version`

## Options Schema

```nix
apps.cli.plakar = {
  enable = lib.mkEnableOption "plakar backup tool";

  # --- Stores (backup destinations) ---
  stores = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        type = lib.mkOption {
          type = lib.types.enum [ "s3" "rclone" ];
          description = "Store backend type.";
        };

        # S3/B2 fields
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

        # Rclone fields (for Google Drive, etc.)
        rcloneRemote = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Name of the rclone remote to import (e.g., 'mydrive'). Requires rclone to be configured.";
        };

        # Common
        passphrase = lib.mkOption {
          type = lib.types.str;
          description = "Kloset store encryption passphrase.";
        };
      };
    });
    default = {};
    description = "Named Plakar stores (backup destinations).";
  };

  # --- Jobs (what to back up, where, when) ---
  jobs = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
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
    });
    default = {};
    description = "Named backup jobs.";
  };

  # No schedule option needed -- Plakar's scheduler handles per-job intervals internally.
};
```

## Example Host Configuration

```nix
apps.cli.plakar = {
  enable = true;

  stores = {
    b2-backup = {
      type = "s3";
      location = "s3://s3.us-west-004.backblazeb2.com/mybucket/plakar";
      accessKey = secrets.plakar.b2_access_key;
      secretAccessKey = secrets.plakar.b2_secret_access_key;
      passphrase = secrets.plakar.passphrase;
    };
    gdrive-backup = {
      type = "rclone";
      rcloneRemote = "gdrive";
      passphrase = secrets.plakar.passphrase;
    };
  };

  jobs = {
    home-to-b2 = {
      store = "@b2-backup";
      paths = [ "/home" ];
      interval = "24h";
      check = true;
    };
    home-to-gdrive = {
      store = "@gdrive-backup";
      paths = [ "/home" ];
      interval = "24h";
    };
  };

};
```

## Config Generation

The module generates YAML files under `/etc/plakar/`:

### `/etc/plakar/stores.yaml` (for S3/B2 stores)

```yaml
b2-backup:
  location: s3://s3.us-west-004.backblazeb2.com/mybucket/plakar
  access_key: <from secrets>
  secret_access_key: <from secrets>
  use_tls: true
  passphrase: <from secrets>
```

### `/etc/plakar/scheduler.yaml`

```yaml
agent:
  tasks:
    - name: home-to-b2
      repository: "@b2-backup"
      backup:
        path: /home
        interval: 24h
        check: true
    - name: home-to-gdrive
      repository: "@gdrive-backup"
      backup:
        path: /home
        interval: 24h
        check: false
```

## Activation and Service Setup

### Activation script (runs on `nixos-rebuild switch`)

1. Import S3/B2 stores: `plakar -config /etc/plakar store import -config /etc/plakar/stores.yaml`
2. Import rclone stores: `rclone config show | plakar -config /etc/plakar store import -rclone <remoteName>` (for each rclone-type store)
3. Initialize any new stores: `plakar -config /etc/plakar at @<store> create` (idempotent -- skip if already initialized)

### Systemd service: `plakar-scheduler.service`

- `ExecStart`: `plakar -config /etc/plakar scheduler start -tasks /etc/plakar/scheduler.yaml -foreground`
- `Type`: `simple`
- `WantedBy`: `multi-user.target`
- `After`: `network-online.target`
- Environment: `PLAKAR_PASSPHRASE` set from secrets

Plakar's scheduler runs as a long-running foreground process with its own per-job interval logic. No systemd timer is needed -- the service starts at boot and stays running. The `schedule` option is removed; intervals are configured per-job.

## Helper CLI: `plakar-mgr`

A Fish script (matching `backup-mgr` pattern) providing:

| Flag | Action |
|------|--------|
| `-init` | Initialize all configured stores |
| `-list` | List snapshots across all stores |
| `-status` | Show systemd service/timer status |
| `-logs` | Show service journal logs |
| `-restore <store> <snapshot>` | Restore a specific snapshot |
| `-check <store>` | Run integrity check on a store |
| `-help` | Show usage |

## Secrets

New secrets file needed: `secrets/plakar.nix`

```nix
{
  b2_access_key = "<backblaze B2 key ID>";
  b2_secret_access_key = "<backblaze B2 application key>";
  passphrase = "<kloset encryption passphrase>";
}
```

These are encrypted via git-crypt like all other secrets.

## Google Drive Setup (One-Time)

The rclone-backed Google Drive store requires a one-time interactive setup:

1. `rclone config` -- select "Google Drive", authenticate via browser
2. This creates `~/.config/rclone/rclone.conf` with the OAuth token
3. On rebuild, the activation script imports this into Plakar

No GCP project or custom OAuth app is needed -- rclone provides a built-in client ID.

## Core Suite Integration

Add to `modules/suites/core/default.nix`:

```nix
apps.cli.plakar.enable = true;
```

## Dependencies

- `pkgs.rclone` -- required for Google Drive store import
- `pkgs.go` -- build-time only (for `buildGoModule`)
- Network access at activation time (for store initialization)

## Out of Scope

- Plakar UI/web interface
- Database source connectors (MySQL, PostgreSQL, Notion)
- Destination connectors (restore-to-remote)
- Retention/prune policies (can be added later via job options)
