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

Use the `zj` wrapper for everyday session work — four verbs (`s`/`a`/`d`/`n`)
with fzf where it adds value, transparent passthrough for everything else.
Tab name-completion is wired up for both `zj` and the raw `zellij attach /
kill-session / delete-session` value slots.

| Command              | What it does                                         |
|----------------------|------------------------------------------------------|
| `zj`                 | list sessions (gate — forces conscious next action)  |
| `zj s`               | list sessions                                        |
| `zj a [<name>]`      | attach (fzf if no name)                              |
| `zj d [<name>...]`   | delete session (fzf if no name; kills active first)  |
| `zj n <name>`        | new named session (or attach if it exists)           |
| `zj n <name> -- <cmd...>` | new named session whose first pane runs `<cmd>` |
| `zj help`            | usage summary                                        |
| `zj <anything else>` | passthrough to `zellij` (e.g. `zj run …`, `zj edit`) |

Examples for `zj n -- <cmd>`:
```
zj n logs   -- tail -F /var/log/syslog
zj n watch  -- watch -n1 'date && uptime'
zj n vim    -- vim README.md
```
The command runs via `sh -c`, so pipes / `&&` / redirects work. Refuses
to start if the session name already exists — `zj d <name>` first, or
`zj a <name>` to attach to the existing one without the `-- <cmd>`.

Bare `zj` deliberately doesn't launch zellij — it lists sessions so you
always see current state and have to consciously pick `zj a` (attach) or
`zj n <name>` (new), avoiding accidental unnamed auto-generated sessions.

`zj d` uses `zellij delete-session --force` — it always succeeds whether
the session is active or already exited. If you ever want kill-but-keep-
recoverable, fall through with `zj kill-session <name>` (zellij's
distinction: `kill-session` leaves an EXITED record you can revive;
`delete-session` removes the record permanently).

Raw `zellij` reference, in case you want it:

| Command                           | What it does           |
|-----------------------------------|------------------------|
| `zellij list-sessions`            | list active sessions   |
| `zellij attach <name>`            | attach to a session    |
| `zellij attach -c <name>`         | create-if-missing      |
| `zellij kill-session <name>`      | kill one               |
| `zellij delete-all-sessions`      | nuke exited sessions   |
