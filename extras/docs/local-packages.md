# Module-Local Package Definitions

Package derivations are no longer centralized under `packages/<name>/default.nix`.

They now live next to the modules that consume them:

- `modules/apps/gui/helium/build/default.nix`
- `modules/apps/gui/insomnia/build/default.nix`
- `modules/apps/cli/mcp-server-sequential-thinking/build/default.nix`
- `modules/apps/cli/claude-code/build/default.nix`

For npm-based package derivations, their lockfiles are colocated in the same module folder.
