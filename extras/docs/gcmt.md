# gcmt

Interactive conventional commit tool. Guides you through file selection, commit type, scope, and summary via a gum UI, then calls an AI to draft the commit body as bullet points for you to review before a signed commit is created.

## Enable

Enabled automatically when `apps.cli.git` is enabled:

```nix
apps.cli.git.enable = true;
```

To enable independently:

```nix
apps.cli.gcmt.enable = true;
```

## Usage

```bash
gcmt [--ai claude|gemini]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--ai <tool>` | `claude` | AI backend to use for body generation |
| `-h, --help` | — | Show help |

## Workflow

### Step 1 — File selection

All changed files are listed in a fuzzy multi-select picker (staged, unstaged, untracked, renamed), each prefixed with a status label:

```
[staged]   src/auth.rs
[unstaged] src/config.rs
[new]      tests/auth_test.rs
[modified] Cargo.lock
```

Space to toggle, Enter to confirm. After confirmation:
- Everything currently staged is unstaged (changes stay in the worktree — nothing is deleted)
- Only the selected files are staged

### Step 2 — Commit type

Choose from all 13 conventional commit types. The emoji is applied automatically.

| Type | Emoji |
|------|-------|
| `feat` | ✨ |
| `fix` | 🐛 |
| `docs` | 📝 |
| `style` | 🎨 |
| `refactor` | ♻️ |
| `perf` | ⚡ |
| `test` | ✅ |
| `build` | 👷 |
| `ci` | 💚 |
| `chore` | 🔧 |
| `revert` | ⏪ |
| `security` | 🔒 |
| `deps` | ⬆️ |

### Step 3 — Scope

Required. Lowercase kebab-case name of the module or area being changed (e.g. `auth`, `api`, `git`).

### Step 4 — Summary

The prompt pre-fills `type(scope): emoji` so you type only the description. Warns if the full subject line exceeds 72 characters.

### Step 5 — AI body generation

The staged diff is sent to claude (or gemini with `--ai gemini`). The AI returns 3–5 imperative bullet points explaining what changed and why. Falls back gracefully if the selected tool is not in PATH.

### Step 6 — Review / edit body

The AI output opens in `gum write` for editing. `ctrl+d` to confirm, `esc` to clear and omit the body entirely.

### Step 7 — Preview + confirm

```
─── Commit Preview ───

feat(auth): ✨ add OAuth2 login flow

- Add OAuth2 provider abstraction with pluggable backends
- Implement PKCE flow for public clients
- Store refresh tokens encrypted at rest
- Wire callback route into existing router
```

`gum confirm` prompts before proceeding.

### Step 8 — Signed commit

```bash
git commit -S -m "feat(auth): ✨ add OAuth2 login flow" -m "- Add OAuth2 ..."
```

SSH signing via the key configured in `apps.cli.git`. Body is omitted from the commit command if left empty.

## Commit message format

```
<type>(<scope>): <emoji> <description>
```

Examples:

```
feat(auth): ✨ add OAuth2 login flow
fix(api): 🐛 resolve race condition in token refresh
chore(git): 🔧 add gcmt conventional commit tool
deps(flake): ⬆️ update flake inputs
```

Rules (matching the `/commit` skill):
- Scope is **required**, lowercase kebab-case
- Emoji goes **after** the colon, before the description
- Description: imperative mood, lowercase start, no trailing period
- Subject line under 72 characters

## Notes

- Requires `git`, `gum`, and coreutils (all in `runtimeInputs`).
- `claude` and `gemini` are optional — body generation is skipped if neither is found.
- AI fallback: if `--ai gemini` is specified but `gemini` is not in PATH, it falls back to `claude`.
- Unstaging uses `git restore --staged -- .` (git ≥ 2.23). Falls back to `git reset HEAD -- .` on older git.
- The body is passed as a second `-m` argument so git formats it as a separate paragraph with a blank line separator, following the git body convention.
