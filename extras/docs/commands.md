# Commands

## Justfile Shortcuts

Core recipes (run from repo root):

- `just rebuild` / `just r` -- production rebuild of current host
- `just dev-rebuild` -- stage all, rebuild, unstage on exit
- `just upgrade` / `just up` -- update flake inputs, rebuild, download voxtype models
- `just update <input>` -- update a single flake input
- `just clean` / `just gc` -- garbage collect (default 5 days, e.g. `just clean 14`)
- `just gc-nuclear` -- deep cleanup (generations + gc + cache + store optimize)
- `just sync-git` -- smart push/pull
- `just health` -- deadnix + statix checks
- `just fmt` -- format nix files via `nix fmt`

Reference recipes: `just ref <recipe>` -- run `just ref` to list.

## Manual Rebuild

```bash
sudo nixos-rebuild switch --flake ".#$(hostname)"    # current host
sudo nixos-rebuild switch --flake .#qbert             # specific host
```

## Flake Maintenance

```bash
nix flake check --show-trace
nix flake update
```

## Claude Code

### Shell Shortcuts

| Command | Description |
|---------|-------------|
| `cc <task>` | Inline headless task -- `claude -p "<task>"` (unrestricted tools) |
| `ask <question>` | Read-only Q&A -- tools restricted to Read, Bash, Glob, Grep |
| `ls \| ask "summarize"` | Pipe stdin into `ask` |

### MCP Servers (per-project)

```bash
mcp-pick    # select servers to activate; writes .mcp.json (gitignored)
```

Available: `kubernetes-mcp-server`, `gopls`, `context7`, `kong-konnect`.

### Output Styles

```
/output compact    # Minimal: code over prose, no preamble/summary
/output           # Reset to default
```

## Backrest

```bash
backrest-ui    # launch + open UI (workstations)
backrest       # manual mode (all hosts); Ctrl+C to stop
```
