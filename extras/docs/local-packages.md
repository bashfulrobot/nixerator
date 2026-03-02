# Module-Local Packages

Package derivations live next to the modules that consume them (not centralized):

- `modules/apps/gui/helium/build/default.nix`
- `modules/apps/gui/insomnia/build/default.nix`
- `modules/apps/cli/mcp-server-sequential-thinking/build/default.nix`
- `modules/apps/cli/claude-code/build/default.nix`

For npm-based packages, lockfiles are colocated in the same module folder.

**Version updates:** edit versions and hashes directly in the `build/default.nix` files above. For npm packages, also update the colocated `package-lock.json`.
