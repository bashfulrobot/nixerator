# Hosts

- Workstations (donkeykong, qbert) auto-import all modules via `../../modules` in configuration.nix. srv does NOT — srv manually imports each module in `modules.nix`, so adding a module to srv requires both the import path AND the enable.
- configuration.nix: imports, archetype, networking. modules.nix: per-host module enables and host-specific option values. Do not mix these roles.
- home.nix sources username, homeDirectory, stateVersion from globals — never hardcode.
- New hosts need a `mkHost` entry in flake.nix with appropriate `extraModules` and `homeManagerModules`.
- `donkeykong` is a laptop and often powered off/unreachable — don't assume SSH access to it. `srv` is an always-on headless server (SSH is the normal way to reach it); `qbert` is a desktop, usually up. To validate a donkeykong-affecting change, use `just build-host donkeykong` (cross-evaluates from wherever it's run, no live connection needed) rather than attempting a live rebuild/switch or SSH check against it.
