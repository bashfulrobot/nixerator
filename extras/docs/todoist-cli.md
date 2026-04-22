# todoist-cli

Official Doist [Todoist CLI](https://todoist.com/cli) (`td`). Packaged from `@doist/todoist-cli` on npm. First-class AI-agent support — ships Claude Code, Codex, Cursor, Gemini, and universal skills on request.

## Enable

```nix
apps.cli.todoist-cli.enable = true;   # also enabled via offcomms suite
```

## Token injection

The module reads `secrets.todoist_token` from `secrets/secrets.json` and injects it as `TODOIST_API_TOKEN` into both `environment.variables` (system-wide) and `home.sessionVariables` (user shells). `td` treats that env var as higher priority than any keyring/config token, so `td` works from any cwd, any shell, any Claude Code subprocess — no `td auth login`, no shadowenv, no per-directory trust.

If `secrets.todoist_token` is missing or empty, no env var is set and `td` falls back to its normal auth flow (`td auth login` or `td auth token`).

## Usage

```bash
td --help
td add "Buy milk tomorrow #Shopping @errand !p1"   # natural-language quick-add
td today                                           # tasks due today + overdue
td inbox                                           # inbox tasks
td task add --help                                 # fine-grained task creation
td task list --project "Work"
td project list
td comment add <task-id> "status note"
td task view https://app.todoist.com/app/task/...
```

## AI-agent skills

`td` can install an agent skill that teaches the coding agent how to use the CLI:

```bash
td skill install claude-code   # ~/.claude/skills/todoist-cli/SKILL.md
td skill install codex
td skill install cursor
td skill install gemini
td skill install universal     # Amp, OpenCode, any ~/.agents/-based agent
td skill list
td skill uninstall <agent>
```

The Nix module does NOT run `td skill install` automatically (it writes to `~/.claude/` and similar). Run it once manually after enabling the module; subsequent CLI updates re-sync the installed skill.

## Read-only mode

For scripts that must not mutate data, use an OAuth token with `data:read` scope:

```bash
td auth login --read-only
```

Token-scope detection is not possible for env-injected tokens (`TODOIST_API_TOKEN` is treated as unknown scope / assumed write-capable). If you need strict read-only, unset the env var and use `td auth login --read-only` instead.

## Shell completions

```bash
td completion install fish   # or bash, zsh
```

## Priority Mapping

| GUI | Quick-add syntax | API value |
| --- | ---------------- | --------- |
| P1  | `!p1`            | 4         |
| P2  | `!p2`            | 3         |
| P3  | `!p3`            | 2         |
| P4  | `!p4` (default)  | 1         |

## Notes

- Token lives in the Nix store (read-only, user-readable) once the module is enabled — same trust model as `GEMINI_API_KEY` in the claude-code module.
- `td`'s postinstall skill-sync step is stripped during the Nix build; run `td skill install <agent>` manually after rebuild.
- Version pinned in `settings/versions.nix` under `cli.todoist-cli`; bump via `just setup::check-updates`.
