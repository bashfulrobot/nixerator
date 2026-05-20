# Zellij — Cheat Sheet

Press `q` to close this overlay (it's `bat --paging=always`).
Press `Esc` or `Enter` inside zellij to leave a mode and return to normal.

## Modes

| Mode    | Enter    | Notable keys                                                     |
|---------|----------|------------------------------------------------------------------|
| Pane    | `Ctrl p` | `n` new · `x` close · `h/j/k/l` focus · `f` floating · `e` fullscreen · `z` frame |
| Tab     | `Ctrl t` | `n` new · `x` close · `h/l` prev/next · `r` rename · `1-9` jump  |
| Resize  | `Ctrl n` | `h/j/k/l` shrink/grow · `=/+/-` increase/decrease                |
| Move    | `Ctrl h` | `h/j/k/l` move pane in direction                                 |
| Scroll  | `Ctrl s` | search scrollback · `e` open in editor                           |
| Session | `Ctrl o` | `d` detach · `w` session manager                                 |
| Quit    | `Ctrl q` | quit zellij                                                      |
| Lock    | `Ctrl g` | toggle locked mode (passes keys through to inner app)            |

## Quick actions (any mode, no prefix)

| Key             | Action                          |
|-----------------|---------------------------------|
| `Alt n`         | new pane                        |
| `Alt h/j/k/l`   | focus pane in direction         |
| `Alt = / +/ -`  | resize                          |
| `Alt [ / ]`     | previous / next tab             |
| `Alt f`         | toggle floating panes           |
| `Alt i / Alt o` | move tab left / right           |

## Sessions (from a regular shell, not inside zellij)

Use the `zj` wrapper for everyday session work — it falls back to an fzf
picker whenever a session name is needed but you didn't pass one, which
covers the gap where `zellij`'s native completions don't suggest names
for `kill-session` / `delete-session`. Tab name-completion for `zj`
(and for raw `zellij attach / kill-session / delete-session`) is wired up
too.

| Command                | What it does                                       |
|------------------------|----------------------------------------------------|
| `zj`                   | fzf-pick an active session and attach              |
| `zj <name>`            | attach to `<name>`, create if missing              |
| `zj ls`                | list sessions                                      |
| `zj kill [<name>...]`  | kill active session (fzf if omitted, Tab=multi)    |
| `zj del  [<name>...]`  | delete session (fzf if omitted, Tab=multi)         |
| `zj clean`             | delete-all-sessions (bulk exited cleanup)          |
| `zj nuke`              | kill all active + delete all, with confirm prompt  |
| `zj help`              | usage summary                                      |
| `zj <anything else>`   | passthrough to `zellij` (e.g. `zj run …`)          |

Raw `zellij` reference, in case you want it:

| Command                           | What it does           |
|-----------------------------------|------------------------|
| `zellij list-sessions`            | list active sessions   |
| `zellij attach <name>`            | attach to a session    |
| `zellij attach -c <name>`         | create-if-missing      |
| `zellij kill-session <name>`      | kill one               |
| `zellij delete-all-sessions`      | nuke exited sessions   |

## Web client (this host)

| Action            | Command                                          |
|-------------------|--------------------------------------------------|
| Create token      | `zellij web --create-token`                      |
| List token names  | `zellij web --list-tokens`                       |
| Revoke one        | `zellij web --revoke-token <name>`               |
| Revoke all        | `zellij web --revoke-all-tokens`                 |
| Server status     | `zellij web --status`                            |

URL: <https://zellij.goat-cloud.ts.net/>
