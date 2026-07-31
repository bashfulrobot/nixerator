# Commands

## Justfile Shortcuts

Core recipes (run from repo root):

- `just rebuild` / `just r` -- production rebuild of current host
- `just upgrade` / `just up` -- update flake inputs, rebuild, download voxtype models
- `just update <input>` -- update a single flake input
- `just bump-hyprflake` -- one command: bump + push hyprflake's inputs in `~/git/hyprflake`, then pull + rebuild here (reverts the lock only if the new pin fails to build)
- `just bump-upsight` -- bump the `upsight` input to latest, rebuild, commit + push `flake.lock`
- `just clean` / `just gc` -- garbage collect (default 5 days, e.g. `just clean 14`)
- `just gc-nuclear` -- deep cleanup (generations + gc + cache + store optimize)
- `just health` -- deadnix + statix checks
- `just fmt` -- format nix files via `nix fmt`

Reference recipes: `just ref <recipe>` -- run `just ref` to list.

Every public root recipe carries a `[group()]`, so `just --list` renders them
grouped: `rebuild`, `bump`, `secrets`, `capture`, `test`, `gc`, `fleet`, `dev`.

## Tests

Each of these runs a bats suite inside a throwaway `nix shell`, so they need no
setup and touch nothing outside `/tmp`. None of them build or activate a
system, so they are all safe to run at any time.

- `just test-secret-guard` -- the claude-code PreToolUse guard hooks
  (secret-leak redaction, primary-tree-write refusal, output scrubbing) plus
  the capture-sync `settings.json` three-way reconcile suite. Sweeps the whole
  `modules/apps/cli/claude-code/cfg/scripts/tests/` directory. **Run it after
  touching any hook script, the capture-sync reconciler, or the secret
  deny-lists** -- these are the guards that stop a secret reaching the model or
  an agent writing into the primary checkout from a worktree.
- `just test-worktree-flow` -- the worktree-flow helpers behind the
  `github-issue` / `hack` skills, mainly the branch preflight that decides
  whether a new worktree can be created and what it bases off. **Run it after
  changing anything under `modules/apps/cli/worktree-flow/`.**
- `just test-render-secrets` -- render-secrets unit tests, currently covering
  the Forgejo `tea` config generation. **Run it after changing the
  render-secrets script or adding a secret whose rendered output is a config
  file rather than a bare value.** It exercises the generator only; it never
  reads real 1Password values.
- `just test-skill-cache` -- the `skill-cache` CLI (the warm name-to-ID cache
  skills use instead of re-querying an external API). **Run it after changing
  `modules/apps/cli/skill-cache/`.**

## Version Management

All pinned package versions are centralized in `settings/versions.nix`.

- `just setup::check-updates` -- check all packages for updates (caches to `/tmp/nixerator-pkg-status.json`)
- `just setup::update-pkg <name>` -- prefetch and write new version+hash for one package
- `just setup::update-pkg --all` -- update all release-tracked packages
- `just setup::update-pkg --all --include-commits` -- also update commit-pinned packages

Non-quiet rebuild recipes show a summary of available updates after a successful rebuild (if cached results exist and are less than 24 hours old).

## Manual Rebuild

```bash
sudo nixos-rebuild switch --impure --flake ".#$(hostname)"    # current host
sudo nixos-rebuild switch --impure --flake .#qbert             # specific host
```

`--impure` is required: `flake.nix` reads the secrets file via
`builtins.readFile` of an absolute string path (gated on
`builtins.pathExists`) so the rendered file at
`~/.config/nixos-secrets/secrets.json` stays out of the Nix store. The
justfile recipes already pass this flag.

## Flake Maintenance

```bash
nix flake check --show-trace
nix flake update
```

## Claude Code

### Shell Shortcuts

| Command                 | Description                                                       |
| ----------------------- | ----------------------------------------------------------------- |
| `cc <task>`             | Inline headless task -- `claude -p "<task>"` (unrestricted tools) |
| `ask <question>`        | Read-only Q&A -- tools restricted to Read, Bash, Glob, Grep       |
| `ls \| ask "summarize"` | Pipe stdin into `ask`                                             |

### MCP Servers (per-project)

```bash
mcp-pick    # select servers to activate; writes .mcp.json (gitignored)
```

Available: `kubernetes-mcp-server`, `gopls`, `context7`, `kong-konnect`, `slack`, `todoist`, `drawio`.

### Skills (per-project)

```bash
skill-pick    # select skills to turn ON here; writes only the diff from default into .claude/settings.local.json (gitignored)
```

Most skills default OFF everywhere (`cfg/skill-defaults.nix` holds the
always-on baseline -- humanizer, commit, text-polish, review-dev/security,
and the handful your global CLAUDE.md names directly). Same UX as `mcp-pick`
now: checked = on. Only writes an override where a pick differs from the
Nix-owned default, so most projects need one `skill-pick` run to turn on
whatever's relevant, nothing more.

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
