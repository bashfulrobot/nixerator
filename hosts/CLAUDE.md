# Hosts

- Workstations (donkeykong, qbert) auto-import all modules via `../../modules` in configuration.nix. srv does NOT — srv manually imports each module in `modules.nix`, so adding a module to srv requires both the import path AND the enable.
- configuration.nix: imports, archetype, networking. modules.nix: per-host module enables and host-specific option values. Do not mix these roles.
- home.nix sources username, homeDirectory, stateVersion from globals — never hardcode.
- New hosts need a `mkHost` entry in flake.nix with appropriate `extraModules` and `homeManagerModules`.
