# User lingering

Why the primary user lingers, which user units that affects, and how to check the
declaration is actually doing something.

## What it does

`users.users.<name>.linger = true` makes NixOS run `loginctl enable-linger` for
that user. The user's systemd manager then starts at boot and keeps running with
no login session attached, so `systemd.user` timers fire on schedule instead of
waiting for someone to log in.

It is declared once, in `modules/system/linger/default.nix`, with no enable
option. Lingering is a property of the primary user rather than of any suite or
archetype, so gating it behind one would leave hosts that skip that suite
silently without it.

Workstations pick that module up through auto-import. srv imports modules by
hand, so `hosts/srv/modules.nix` carries the path explicitly, the same way it
does for every other module srv uses.

Wiring it once per host matters. An earlier revision of this change listed the
module in `lib/mkHost.nix` *and* let auto-import find it, on the theory that a
duplicate import is harmless. It is not quite. The two paths produce different
module keys, so the module is evaluated twice and the list-typed `after` below
is concatenated rather than deduplicated, which shows up in the built unit as a
repeated `After=` entry.

## Why it kept disappearing

The declaration used to live in whichever module happened to want it. The
claude-remote module owned it until `66ceaa0a`, then noclaw until `eb735f82`
retired its user service and dropped the line with it. Neither removal broke
anything visible, so neither got noticed.

The reason is that NixOS only runs `disable-linger` for a user set explicitly to
`false`. For `null`, which is what you get when nothing declares the option, it
does nothing at all. The on-disk flag in `/var/lib/systemd/linger` therefore
outlived the declaration that created it. Hosts that had once lingered kept
lingering, while a fresh install would not have reproduced it.

## Linger=yes is not evidence

Because of that asymmetry, `loginctl show-user <name>` reporting `Linger=yes` on
an existing host proves nothing about the configuration. It reads `yes` whether
the option is declared, absent, or was deleted three releases ago.

Check the built system instead:

```
just build-host qbert
grep lingeringUserNames result/etc/systemd/system/linger-users.service
```

`lingeringUserNames` must contain the user. The same file should carry
`After=systemd-logind.service home-manager-<name>.service`.

## Ordering against home-manager

`linger-users.service` is ordered after `home-manager-<name>.service` so a first
boot cannot start the user manager before `~/.config/systemd/user` exists. Both
units are `WantedBy=multi-user.target`, so both have jobs in the boot
transaction and the ordering applies. Without it, first boot can reach
`timers.target` with nothing installed into it. sd-switch reconciles on the next
activation, but first boot is the case the declaration exists for.

The ordering is guarded on `users.manageLingering`, since that option is what
defines `linger-users.service` upstream. Setting only `.after` on an otherwise
undefined service would generate a unit with no `ExecStart`.

## Which user units this affects

Lingering starts the user manager at boot, so anything installed into
`default.target` or `timers.target` now runs with no session. Units bound to
`graphical-session.target` are unaffected and still wait for a session.

| Unit | Install target | Headless behaviour |
|------|----------------|--------------------|
| `ballpoint-probe.timer` | `timers.target` | Fine. Reads its Todoist token from `~/.config/nixos-secrets/secrets.json`, no session needed. `OnStartupSec` now counts from boot, which is what a prewarm wants. |
| `hyprflake-updates.timer` | `timers.target` | Fine. The script writes its state file before notifying and guards `notify-send` with `\|\| true`, so only the desktop popup is skipped. The fish notice still appears at the next interactive shell. |
| `aha-fr-report.timer` | `timers.target` | Fine, and this is the unit that benefits most. See the gws note below. |
| `dsearch.service` | `default.target` | Behaviour change. Starts at boot and no longer stops at logout. Owned by hyprflake's dank module, not by this repo, so it is not changed here. Worth revisiting on the laptop if a filesystem indexer running on battery after logout is unwanted. |
| `insync.service` | `graphical-session.target` | Unaffected, still session-bound. |

## gws does not need the login keyring

It is tempting to assume anything touching Google credentials has to be bound to
`graphical-session.target` so it can reach an unlocked session keyring. For gws
that is wrong, and binding the report that way would stop it running on a
machine that reboots unattended, which is the whole point of lingering.

gws keeps credentials in `~/.config/gws/credentials.enc`, decrypted with a key
that the `file` backend stores in `~/.config/gws/.encryption_key`. Checked by
pointing `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` at a copy of the config with the token
cache removed, forcing a refresh, and `DBUS_SESSION_BUS_ADDRESS` at a dead
socket. An authenticated Drive call still succeeded. Deleting `.encryption_key`
from that copy is what turned it into `Decryption failed`.

The default `keyring` backend reaches the same file by silent fallback when no
session bus is available. `aha-fr-report.service` sets
`GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file` so the behaviour is pinned rather
than depending on an undocumented fallback.

Never run `gws auth export` to investigate this. It prints decrypted credentials
to stdout.
