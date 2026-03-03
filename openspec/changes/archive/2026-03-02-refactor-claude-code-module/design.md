## Context

`modules/apps/cli/claude-code/default.nix` is 876 lines containing six distinct concerns in a single file: MCP server definitions, LSP plugin definitions, inline shell scripts (~340 lines of fish/bash), a permissions allow-list, hooks, and fish shell integration. The module already uses external files for agents, skills, output styles, and the statusline script — but the core configuration is monolithic.

The repo's auto-import system (`lib/autoimport.nix`) excludes paths containing `"cfg"` via `hasInfix` matching, and the `cfg/` directory convention is already established in `modules/apps/gui/vscode/cfg/`. Sub-files placed in `cfg/` are invisible to auto-import and must be explicitly imported from `default.nix`.

## Goals / Non-Goals

**Goals:**
- Break the monolith into focused, single-concern files under `cfg/`
- Keep `default.nix` as a slim spine (~120 lines) that imports and assembles fragments
- Extract inline shell scripts to real `.fish`/`.bash` files for editor support and linting
- Produce identical build output — zero behavioral changes

**Non-Goals:**
- No new NixOS/HM options — this is file-level decomposition only, not option-gated submodules
- No changes to the auto-import system itself
- No refactoring of the module's feature set (MCP servers, LSP plugins, hooks, etc. stay as-is)
- No changes to the `build/`, `agents/`, `skills/`, or `output-styles/` directories

## Decisions

### 1. Use `cfg/` for all configuration fragments

**Choice**: Place all extracted `.nix` files under `cfg/`, shell scripts under `cfg/scripts/`.

**Why over alternatives**:
- `cfg/` is already in the `defaultExcludes` list in `lib/autoimport.nix` — no risk of double-import
- Established convention in the repo (`vscode/cfg/`)
- A `lib/` or `parts/` directory would require adding new exclusion patterns to `autoimport.nix`

### 2. Explicit-arg function imports, not `callPackage` or `mkMerge`

**Choice**: Each `cfg/*.nix` file is either a function taking an attrset (`{ lib, pkgs, ... }:`) or a bare expression. Imported via `import ./cfg/file.nix { inherit ...; }`.

**Why over alternatives**:
- `callPackage` auto-injects from `pkgs`/`lib` and implies a derivation interface (`override`/`overrideAttrs`) — misleading for configuration data, and doesn't support custom args like `secrets` or `kubeconfigFile` without overrides
- `mkMerge` is for combining multiple `config` blocks that set overlapping NixOS options with priority resolution — these fragments provide data to a single `config` block, not competing option definitions
- Explicit args make the dependency graph visible at each call site

### 3. Bare expression for permissions.nix

**Choice**: `cfg/permissions.nix` is a plain list literal with no function wrapper. Imported as `permissions = import ./cfg/permissions.nix;`.

**Why**: It's a pure list of strings with zero dependencies on `lib`, `pkgs`, or anything else. A function wrapper would add ceremony for no benefit.

### 4. Extract inline scripts to real shell files

**Choice**: Move k8s-mcp-setup (~275 lines of fish) to `cfg/scripts/k8s-mcp-setup.fish` and mcp-pick (~65 lines of bash) to `cfg/scripts/mcp-pick.bash`.

**Why over keeping as Nix strings**:
- Enables editor syntax highlighting, shellcheck/fish linting
- Eliminates confusing `''${}` Nix escape sequences in the bash script
- Makes scripts directly testable (`bash -n`, `fish -n`)

**Interpolation handling**:
- **k8s-mcp-setup**: Uses one Nix interpolation (`"${kubeconfigFile}"`). Replace with `@KUBECONFIG_FILE@` placeholder in the `.fish` file, substituted via `builtins.replaceStrings` at the import site in `default.nix`.
- **mcp-pick**: No Nix interpolations — only `''${}` escape sequences that become plain `${}` in a real bash file. Use `builtins.readFile` directly.

### 5. Fish config returns the programs.fish attrset directly

**Choice**: `cfg/fish.nix` returns `{ functions = { ... }; shellAbbrs = { ... }; }` — the exact attrset assigned to `programs.fish` in `default.nix`.

**Why**: Keeps the assignment in the spine simple (`fish = fishConfig;`) and avoids nesting mistakes (`{ fish = { ... } }` would be wrong).

## Risks / Trade-offs

**Risk: k8s-mcp-setup placeholder substitution** — If `@KUBECONFIG_FILE@` appears elsewhere in the fish script or is accidentally removed, the substitution silently fails. → Mitigation: The placeholder is on a clearly marked `set -l KUBECONFIG_FILE` line. A post-refactor `nix eval` comparison catches any mismatch.

**Risk: Path-relative imports inside `cfg/*.nix`** — A `cfg/mcp-servers.nix` file that tries `builtins.readFile ./sibling.nix` resolves relative to `cfg/`, not `default.nix`. → Mitigation: None of the fragments use relative `readFile` — they receive everything they need via function args. Only `default.nix` uses relative paths.

**Risk: Forgetting to update an import after adding a new concern** — When someone adds a new configuration area, they must remember to create a `cfg/` file AND import it in `default.nix`. → Mitigation: This is the same pattern as `agents/*.md` — established convention. The spine's import block serves as a clear table of contents.

**Trade-off: More files to navigate** — 7 new files vs 1 monolith. → Accepted: Each file is small and single-purpose. The `cfg/` directory name signals "consumed by parent" and the files are named after their concern.
