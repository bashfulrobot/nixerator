## ADDED Requirements

### Requirement: Configuration fragments live in cfg/ directory
All extracted configuration fragments SHALL be placed under `modules/apps/cli/claude-code/cfg/`. Shell scripts SHALL be placed under `cfg/scripts/`. No configuration fragment SHALL be placed outside `cfg/` or in a directory that is not excluded from auto-import.

#### Scenario: cfg/ directory excluded from auto-import
- **WHEN** the NixOS module auto-import system scans `modules/`
- **THEN** no `.nix` file under `cfg/` is imported as a standalone module, because `lib/autoimport.nix` excludes paths containing the substring `"cfg"` via `hasInfix` matching

#### Scenario: Non-Nix files ignored by auto-import
- **WHEN** shell scripts (`.fish`, `.bash`) exist under `cfg/scripts/`
- **THEN** the auto-import system ignores them, because it only processes files with `.nix` suffix

### Requirement: default.nix is the sole module entry point
`default.nix` SHALL remain the only file auto-imported as a NixOS module for the claude-code directory. It SHALL explicitly import all `cfg/*.nix` fragments. No fragment SHALL be importable as a standalone module.

#### Scenario: Single entry point after refactor
- **WHEN** the auto-import system processes `modules/apps/cli/claude-code/`
- **THEN** only `default.nix` is discovered and imported (same as before the refactor)

#### Scenario: All fragments explicitly imported
- **WHEN** `default.nix` is evaluated
- **THEN** it contains explicit `import ./cfg/<name>.nix` calls for every configuration fragment: `mcp-servers.nix`, `lsp-plugins.nix`, `permissions.nix`, `hooks.nix`, and `fish.nix`

### Requirement: Fragments use explicit-arg function pattern
Each `cfg/*.nix` file that requires external bindings SHALL be a function taking an attrset of its dependencies. Files with zero dependencies SHALL be bare expressions. The `callPackage` pattern and `lib.mkMerge` SHALL NOT be used.

#### Scenario: Function fragment with dependencies
- **WHEN** `cfg/mcp-servers.nix` is imported
- **THEN** it is called as `import ./cfg/mcp-servers.nix { inherit lib pkgs secrets kubernetesMcpServer kubeconfigFile; }` with all required bindings passed explicitly

#### Scenario: Bare expression fragment
- **WHEN** `cfg/permissions.nix` is imported
- **THEN** it is called as `import ./cfg/permissions.nix` and evaluates directly to a list of strings with no function wrapper

### Requirement: Each fragment covers a single concern
The module SHALL be decomposed into exactly these fragments, each covering one concern:

| Fragment | Concern | Returns |
|---|---|---|
| `cfg/mcp-servers.nix` | MCP server definitions + home file generation | Attrset with `mcpServers` and `files` |
| `cfg/lsp-plugins.nix` | LSP plugin definitions + home file generation | Attrset with `files` |
| `cfg/permissions.nix` | Permissions allow-list | List of strings |
| `cfg/hooks.nix` | SessionStart, PostToolUse, Stop hooks | Attrset with hook definitions |
| `cfg/fish.nix` | Fish functions and abbreviations | Attrset matching `programs.fish` shape |
| `cfg/scripts/k8s-mcp-setup.fish` | Kubernetes MCP setup script | Plain fish script (read via `builtins.readFile`) |
| `cfg/scripts/mcp-pick.bash` | MCP server picker script | Plain bash script (read via `builtins.readFile`) |

#### Scenario: MCP servers fragment returns expected shape
- **WHEN** `cfg/mcp-servers.nix` is evaluated with its dependencies
- **THEN** it returns an attrset containing `mcpServers` (server definitions) and `files` (home file mappings for `.claude/mcp-servers/*/`)

#### Scenario: Fish fragment returns programs.fish shape
- **WHEN** `cfg/fish.nix` is evaluated
- **THEN** it returns `{ functions = { ... }; shellAbbrs = { ... }; }` matching the shape expected by `programs.fish`

### Requirement: Inline scripts extracted to real shell files
The k8s-mcp-setup fish script and mcp-pick bash script SHALL be extracted from Nix string literals to real shell files under `cfg/scripts/`.

#### Scenario: k8s-mcp-setup placeholder substitution
- **WHEN** `cfg/scripts/k8s-mcp-setup.fish` is read by `default.nix`
- **THEN** `builtins.replaceStrings` SHALL substitute `@KUBECONFIG_FILE@` with the computed `kubeconfigFile` path before passing to `writeScriptBin`

#### Scenario: mcp-pick eliminates Nix escaping
- **WHEN** `cfg/scripts/mcp-pick.bash` is read by `default.nix`
- **THEN** it is used via plain `builtins.readFile` with no interpolation or substitution needed, and the file contains standard bash `${}` syntax (no `''${}` Nix escaping)

### Requirement: Build output is identical before and after refactor
The refactor SHALL produce identical build output. The generated `settings.json`, home files, system packages, and fish configuration SHALL be byte-identical to the pre-refactor output.

#### Scenario: Home file keys unchanged
- **WHEN** `nix eval` is run on `home-manager.users.<user>.home.file` before and after the refactor
- **THEN** the set of file paths (keys) is identical

#### Scenario: Settings JSON unchanged
- **WHEN** `nix eval` is run on `home-manager.users.<user>.programs.claude-code.settings` before and after the refactor
- **THEN** the JSON output is identical

#### Scenario: System packages unchanged
- **WHEN** `nix eval` is run on `environment.systemPackages` before and after the refactor
- **THEN** the package set is identical

### Requirement: default.nix spine is under 150 lines
After refactoring, `default.nix` SHALL contain only: module arguments, the `let` block with shared bindings and import calls, the `options` block, and the `config = lib.mkIf` assembly block. It SHALL NOT exceed 150 lines.

#### Scenario: Spine line count
- **WHEN** the refactored `default.nix` is measured with `wc -l`
- **THEN** the result is 150 lines or fewer
