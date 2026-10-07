# Hosts

- The workstation (qbert) auto-imports all modules via `../../modules` in configuration.nix. srv does NOT — srv manually imports each module in `modules.nix`, so adding a module to srv requires both the import path AND the enable.
- configuration.nix: imports, archetype, networking. modules.nix: per-host module enables and host-specific option values. Do not mix these roles.
- home.nix sources username, homeDirectory, stateVersion from globals — never hardcode.
- New hosts need a `mkHost` entry in flake.nix with appropriate `extraModules` and `homeManagerModules`.
- `srv` is an always-on headless server (SSH is the normal way to reach it); `qbert` is a desktop, usually up. To validate a change for a host you are not on, use `just build-host <host>` (cross-evaluates from wherever it's run, no live connection needed) rather than attempting a live rebuild/switch or SSH check.
