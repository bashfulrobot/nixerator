# gcmt

Interactive conventional commit tool with AI-generated body.

## Enable

Enabled automatically with `apps.cli.git.enable = true;`, or independently: `apps.cli.gcmt.enable = true;`

## Usage

```bash
gcmt [--ai claude|gemini]
```

Default AI backend: `claude`. Falls back gracefully if tool is not in PATH.

## Workflow

1. **File selection** -- fuzzy multi-select picker (staged/unstaged/untracked/renamed). Space to toggle, Enter to confirm. Only selected files are staged.
2. **Commit type** -- choose from 13 conventional types (emoji auto-applied)
3. **Scope** -- required, lowercase kebab-case (e.g. `auth`, `api`, `git`)
4. **Summary** -- pre-filled `type(scope): emoji`, you type the description. Warns if >72 chars.
5. **AI body** -- staged diff sent to AI, returns 3-5 imperative bullet points. Skipped if tool not found.
6. **Edit body** -- review/edit in `gum write`. `ctrl+d` to confirm, `esc` to omit.
7. **Preview + confirm** -- full commit message shown, `gum confirm` before proceeding.
8. **Signed commit** -- `git commit -S` with SSH signing.

## Commit Types

| Type       | Emoji | Type       | Emoji |
| ---------- | ----- | ---------- | ----- |
| `feat`     | ✨    | `perf`     | ⚡    |
| `fix`      | 🐛    | `test`     | ✅    |
| `docs`     | 📝    | `build`    | 👷    |
| `style`    | 🎨    | `ci`       | 💚    |
| `refactor` | ♻️    | `chore`    | 🔧    |
| `revert`   | ⏪    | `security` | 🔒    |
| `deps`     | ⬆️    |            |       |

## Format Rules

```
<type>(<scope>): <emoji> <description>
```

- Scope: required, lowercase kebab-case
- Emoji: after colon, before description
- Description: imperative mood, lowercase start, no trailing period
- Subject line: under 72 characters

## Notes

- Requires `git`, `gum`, coreutils (all in `runtimeInputs`)
- Body passed as second `-m` arg (git formats with blank line separator)
- Unstaging: `git restore --staged -- .` (git >= 2.23), falls back to `git reset HEAD -- .`
