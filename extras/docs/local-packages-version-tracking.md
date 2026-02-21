# Version Tracking for Module-Local Packages

Package version tracking is module-local.

Update versions and hashes directly in the package files listed below:

- `modules/apps/gui/helium/build/default.nix`
- `modules/apps/gui/insomnia/build/default.nix`
- `modules/apps/cli/termly/build/default.nix`
- `modules/apps/cli/yepanywhere/build/default.nix`
- `modules/apps/cli/mcp-server-sequential-thinking/build/default.nix`
- `modules/apps/cli/claude-code/build/default.nix`

For npm packages, update both the derivation and the colocated `package-lock.json` in the same module folder.
