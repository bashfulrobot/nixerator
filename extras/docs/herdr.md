# herdr

[herdr](https://herdr.dev) is a multiplexer for coding agents. It runs Claude
Code (and Codex, and ~20 other CLIs it detects) under a background server, so
closing a terminal, dropping an SSH connection or rebooting does not end a
session — and the sidebar shows which agents are working, blocked, or idle.

It is not a `zellij` replacement. zellij multiplexes shells; herdr multiplexes
agents. Both are installed on every host.

The same tool, with the same config, is installed on the Mac by the
[donkeykong](https://github.com/bashfulrobot/donkeykong) repo (`Brewfile.core` +
a chezmoi-managed `~/.config/herdr/config.toml`). herdr reads the same path on
Linux and macOS, so keep the two in step: a setting changed here should change
there.

## Where it comes from

`modules/apps/cli/herdr`, package `pkgs.llm-agents.herdr` — the `llm-agents`
flake input (numtide/llm-agents.nix) that already supplies `claude-code` and
`opencode`. No separate flake input, no pin in `settings/versions.nix`:
`just quiet-upgrade` (`qu`) moves herdr with everything else.

Do **not** run `herdr update`. herdr's own docs reserve it for installs made by
their installer script, and here it would replace the Nix-managed binary behind
Nix's back. The config sets `update.version_check = false` for the same reason:
the in-app upgrade notice points at exactly that command.

## Which hosts

| Host | Enabled by |
| --- | --- |
| donkeykong, qbert | `suites.ai` (via `archetypes.workstation`) |
| srv | cherry-picked in `hosts/srv/modules.nix`, like the rest of the Claude Code stack |

srv is the strongest case for it: a session started over SSH outlives the SSH
connection, which is the same promise `archetypes.claudeWorkHost` already makes
with zellij — zellij for the shells, herdr for the agents inside them.

## Config

`~/.config/herdr/config.toml`, written from the `configToml` string in
`modules/apps/cli/herdr/default.nix`:

```sh
$EDITOR ~/git/nixerator/modules/apps/cli/herdr/default.nix
just qr
herdr server reload-config    # or `reload config` from the global menu
```

Reload covers most UI settings without restarting panes; startup-only settings
need a fresh `herdr`.

Only settings that depart from a herdr default live there, each with the reason
inline. `herdr --default-config` prints the full default set and the
[config reference](https://herdr.dev/docs/config-reference/) documents every key
— read them there rather than pasting either into the module, which would pin
values this repo never meant to choose.

**herdr's in-app settings panel cannot save here.** `xdg.configFile` deploys a
read-only symlink into the Nix store, so the panel (and `herdr config
reset-keys`) will fail to write. That is the trade for having Nix own the file
rather than a capture loop; change settings in the module. This is the one place
the NixOS side behaves differently from the Mac, where chezmoi leaves a writable
file and `just doctor` reports the drift afterwards.

## The Claude Code hook

`herdr integration install claude` writes `~/.claude/hooks/herdr-agent-state.sh`
and adds hook entries to `~/.claude/settings.json`. Without it herdr still runs
Claude Code, but it infers each agent's state by reading the screen instead of
being told, and cannot restore a pane into its native conversation session.

On the Mac this is a per-machine step you run by hand, because
`~/.claude/settings.json` is deliberately unmanaged there. Here it cannot be:
`modules/apps/cli/claude-code/cfg/activation.nix` rewrites `settings.json` from
the repo copy on every rebuild, so a hand-run install would be silently reverted
by the next `just qr`. The herdr module therefore re-runs the installer at
activation, ordered *after* that rewrite. The command is idempotent.

Two consequences worth knowing:

- The hook entries it adds are stripped back out on capture
  (`modules/apps/cli/claude-code/cfg/fish.nix`), so the repo's `settings.json`
  never gains a home-only path that other hosts cannot resolve. Every other
  Nix-owned hook is caught by the generic "command lives under `/nix/store`"
  rule; this one is named explicitly because herdr's script does not.
- `apps.cli.herdr.claudeIntegration.enable` defaults to
  `apps.cli.claude-code.enable`. Set it to `false` to keep `~/.claude`
  untouched by this module.

Check it with `herdr integration status`.
