## Why

The Claude Code module (`modules/apps/cli/claude-code/default.nix`) is an 876-line monolith mixing data definitions, inline scripts, permissions lists, hooks, fish shell config, and the module spine in a single file. Finding and editing any one concern requires scrolling past unrelated code. Breaking it into focused files makes each concern independently editable without touching the rest.

## What Changes

- Extract MCP server definitions and home file generation into `cfg/mcp-servers.nix`
- Extract LSP plugin definitions and home file generation into `cfg/lsp-plugins.nix`
- Extract the 138-line permissions allow-list into `cfg/permissions.nix` (bare list, no function wrapper)
- Extract SessionStart, PostToolUse, and Stop hooks into `cfg/hooks.nix`
- Extract Fish functions and abbreviations into `cfg/fish.nix`
- Move the ~275-line k8s-mcp-setup inline fish script to `cfg/scripts/k8s-mcp-setup.fish` (real file, `@KUBECONFIG_FILE@` placeholder substituted at build time)
- Move the ~65-line mcp-pick inline bash script to `cfg/scripts/mcp-pick.bash` (real file, eliminates `''${}` Nix escaping)
- Reduce `default.nix` to a ~120-line spine: module args, imports, options, and config assembly

No new options. No option-gated submodules.

### Auto-import safety

The module auto-import system (`lib/autoimport.nix`) recursively discovers all `.nix` files under `modules/` and imports them as NixOS modules. It excludes any file whose path contains a `defaultExcludes` substring — `"disabled"`, `"build"`, `"cfg"`, or `"reference"` — via `hasInfix` matching (line 38). This means:

- **All files under `cfg/`** are excluded from auto-import. The `cfg` substring in the path triggers the filter. No `.nix` file placed there will be picked up as a standalone module.
- **Non-`.nix` files** (`.fish`, `.bash`) are also ignored — the filter requires `hasSuffix ".nix"`.
- **`default.nix` is the only module** the auto-import sees for claude-code. It remains the sole entry point.

The new `cfg/*.nix` files are imported **explicitly** from `default.nix` via `import ./cfg/file.nix { ... }`. This is the same pattern used by `modules/apps/gui/vscode/cfg/` and `modules/apps/cli/*/build/` throughout the repo.

## Capabilities

### New Capabilities

- `module-decomposition`: File structure and import pattern for breaking the monolith into `cfg/` fragments using explicit-arg functions and bare expressions

### Modified Capabilities

_(none — no existing specs to modify)_

## Impact

- **Files changed**: `modules/apps/cli/claude-code/default.nix` (rewritten to ~120 lines)
- **Files created**: `cfg/mcp-servers.nix`, `cfg/lsp-plugins.nix`, `cfg/permissions.nix`, `cfg/hooks.nix`, `cfg/fish.nix`, `cfg/scripts/k8s-mcp-setup.fish`, `cfg/scripts/mcp-pick.bash`
- **Import pattern**: `import ./cfg/file.nix { inherit lib pkgs ...; }` for functions, `import ./cfg/permissions.nix` for bare data
- **Script extraction**: k8s-mcp-setup uses `builtins.replaceStrings` with `@KUBECONFIG_FILE@` placeholder; mcp-pick uses plain `builtins.readFile` (no interpolation needed)
- **Verification**: `nix eval` on `home.file` keys and `programs.claude-code.settings` JSON should produce identical output before and after
- **Zero behavioral changes** — the generated settings.json, home files, and system packages remain identical
