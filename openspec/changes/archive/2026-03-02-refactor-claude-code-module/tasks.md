## 1. Capture pre-refactor baseline

- [x] 1.1 Record current `nix eval` output for `home.file` keys, `programs.claude-code.settings` JSON, and `environment.systemPackages` to use as comparison baseline after refactor

## 2. Create directory structure

- [x] 2.1 Create `modules/apps/cli/claude-code/cfg/` and `cfg/scripts/` directories

## 3. Extract shell scripts to real files

- [x] 3.1 Extract k8s-mcp-setup fish script (lines 184-458) to `cfg/scripts/k8s-mcp-setup.fish`, replacing the `"${kubeconfigFile}"` Nix interpolation with `@KUBECONFIG_FILE@` placeholder and removing the Nix string quoting
- [x] 3.2 Extract mcp-pick bash script (lines 462-527) to `cfg/scripts/mcp-pick.bash`, converting `''${` Nix escapes back to plain `${` bash syntax and removing the Nix string quoting

## 4. Extract Nix configuration fragments

- [x] 4.1 Create `cfg/mcp-servers.nix` — function taking `{ lib, pkgs, secrets, kubernetesMcpServer, kubeconfigFile }`, returning `{ mcpServers = ...; files = ...; }` with MCP server definitions (lines 16-61) and home file generation logic
- [x] 4.2 Create `cfg/lsp-plugins.nix` — function taking `{ lib }`, returning `{ files = ...; }` with LSP plugin definitions (lines 65-174) and home file generation logic
- [x] 4.3 Create `cfg/permissions.nix` — bare list expression containing the permissions allow-list (lines 586-722), no function wrapper
- [x] 4.4 Create `cfg/hooks.nix` — function taking `{ lib }`, returning attrset with `SessionStart`, `PostToolUse`, and `Stop` hook definitions (lines 726-798)
- [x] 4.5 Create `cfg/fish.nix` — bare expression returning `{ functions = { ... }; shellAbbrs = { ... }; }` matching the `programs.fish` shape (lines 827-869)

## 5. Rewrite default.nix spine

- [x] 5.1 Rewrite `default.nix` to import all `cfg/` fragments with explicit args, wire them into the single `config = lib.mkIf cfg.enable` block, and keep the module under 150 lines

## 6. Verify build equivalence

- [x] 6.1 Run `nix eval` on `home.file` keys and `programs.claude-code.settings` JSON, diff against pre-refactor baseline to confirm identical output
- [x] 6.2 Run `nix flake check` to verify no evaluation errors
