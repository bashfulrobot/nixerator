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
