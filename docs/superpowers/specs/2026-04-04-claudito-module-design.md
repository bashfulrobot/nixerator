# Claudito Module Design Spec

## Overview

NixOS module for [claudito](https://github.com/comfortablynumb/claudito), a web-based dashboard for orchestrating multiple Claude Code agents across projects. Runs as an always-on systemd user service, accessible over LAN and Tailscale.

## Module Location

- Path: `modules/server/claudito/default.nix`
- Namespace: `server.claudito`
- Enabled via: `suites.ai` (added to `modules/suites/ai/default.nix`)

## Installation

`buildNpmPackage` derivation fetched from the npm registry (matching the clay module pattern). Uses `makeWrapper` to create the `claudito` binary. Node.js >= 20 is a build dependency. Note: `node-pty` native bindings require `python3` and `pkg-config` in `nativeBuildInputs`.

## Module Options

```nix
server.claudito = {
  enable = lib.mkEnableOption "Claudito agent dashboard";

  port = lib.mkOption {
    type = lib.types.port;
    default = 3131;
    description = "Port for the claudito web server.";
  };

  host = lib.mkOption {
    type = lib.types.str;
    default = "0.0.0.0";
    description = "Host/interface to bind to.";
  };

  username = lib.mkOption {
    type = lib.types.str;
    default = "dustin";
    description = "Username for claudito web auth.";
  };

  password = lib.mkOption {
    type = lib.types.str;
    default = "claudito";
    description = "Password for claudito web auth.";
  };

  maxAgents = lib.mkOption {
    type = lib.types.int;
    default = 3;
    description = "Maximum concurrent Claude agents.";
  };

  devMode = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable experimental features (Git tab, etc).";
  };

  projectPaths = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Additional project discovery paths.";
  };

  # Note: Slack and GitHub integrations are configured through
  # claudito's web UI, not via environment variables or secrets.
  # Tokens are stored in ~/.claudito/ settings by the application.
};
```

## Systemd User Service

The service runs under the user's systemd scope, not as a system service. This is required because claudito needs access to:

- `~/.claude/` (Claude Code auth and config)
- `~/.claudito/` (claudito's own state, project registry, conversation history)
- User project directories

### Service definition

```nix
systemd.user.services.claudito = {
  Unit = {
    Description = "Claudito - Claude Code Agent Dashboard";
    After = [ "network-online.target" ];
  };

  Service = {
    ExecStart = "claudito";
    Restart = "always";
    RestartSec = 10;
    Environment = [
      "PORT=3131"
      "HOST=0.0.0.0"
      "CLAUDITO_USERNAME=dustin"
      "CLAUDITO_PASSWORD=claudito"
      "MAX_CONCURRENT_AGENTS=3"
      # Conditionally added:
      # "CLAUDITO_DEV_MODE=1"
      # "CLAUDITO_PROJECT_PATHS=/path/one:/path/two"
    ];
  };

  Install = {
    WantedBy = [ "default.target" ];
  };
};
```

### Session Persistence

No `loginctl enable-linger` needed — existing user services in this codebase (sled, termly) don't use it. The service starts with the user session via `WantedBy = [ "default.target" ]` and persists through Home Manager's systemd integration.
'';
```

## Secrets

No secrets wiring needed. Slack and GitHub integration tokens are configured through claudito's web UI and stored in `~/.claudito/` by the application itself.

The claudito username/password live in Nix module options (visible in Nix store only, not in git).

## Suite Integration

Add to `modules/suites/ai/default.nix`:

```nix
server.claudito.enable = true;
```

## Dependencies

- Node.js >= 20 (from nixpkgs, build dependency)
- Claude Code CLI (already provided by `apps.cli.claude-code`)
- python3, pkg-config (build dependencies for node-pty)
- Network connectivity
- Firewall port opened for LAN/Tailscale access

## Access

- Local: `http://localhost:3131`
- LAN/Tailscale: `http://<host-ip>:3131`
- Auth: username/password prompt on first access
