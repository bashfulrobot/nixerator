# Helper Scripts

## reset-home-permissions.sh

Fixes permissions on `~/.ssh/`, `~/.gnupg/`, and home directory ownership.

```bash
./extras/helpers/reset-home-permissions.sh       # as user
sudo ./extras/helpers/reset-home-permissions.sh  # detects real user
```

**What it sets**: SSH dir 700, private keys 600, public keys 644, config/authorized_keys 600, known_hosts 644, gnupg dir 700, all gnupg files 600.

**When to use**: SSH/GPG auth failures, after restoring from backup, after copying keys between systems, "permissions too open" errors.

If issues persist after running: `gpgconf --kill gpg-agent` and `systemctl --user restart gcr-ssh-agent`, or log out/in.

## voxtype-discovery.sh

Collects hardware and driver information for GPU/audio diagnostics. Outputs a timestamped discovery file.

```bash
./extras/helpers/voxtype-discovery.sh                          # default output in extras/helpers/
./extras/helpers/voxtype-discovery.sh /tmp/discovery.txt       # custom output path
```

Gathers: PCI devices, kernel modules, DRI render nodes, ALSA/PulseAudio state, and Nix package versions. Useful when diagnosing GPU or audio issues on a new host.

## bootstrap-install-secrets.sh

Interactive live-USB orchestrator for the nixerator secrets pipeline during a
fresh NixOS install. Wraps `setup-op-service-account.sh` + `render-secrets-bootstrap.sh`
with prereq checks, prompts, and copy-into-/mnt semantics so the user can
follow `bootstrap.txt` without inlining six error-prone commands.

**Prerequisites**: Nix with flakes; 1Password account credentials handy
(email, secret key, password) — `op signin` is interactive and runs from
the live USB. SA token already exists in your Personal vault for
`op read`. NIX_PATH set (which it is on a NixOS live USB; the helper uses
`nix-shell -p _1password-cli`).

**Two subcommands, both interactive (confirm prompts before destructive
actions, print next-step guidance after):**

```bash
# Run BEFORE `sudo nixos-install` -- stages token + renders secrets
# into /home/dustin/.config/... so the install eval can read them.
sudo ./extras/helpers/bootstrap-install-secrets.sh stage

# Run AFTER `sudo nixos-install`, BEFORE reboot -- copies the staged files
# into /mnt/home/dustin/.config/... and chowns them via nixos-enter.
sudo ./extras/helpers/bootstrap-install-secrets.sh promote
```

Idempotent (the underlying helpers no-op when the destination already
matches). `stage` bails if not run as root or if op isn't signed in;
`promote` bails if /mnt isn't mounted, the staged files don't exist, or
the install user doesn't yet exist on the target.

**Override the install user** (default `dustin`, matching `settings/globals.nix`):

```bash
INSTALL_USER=alice sudo ./extras/helpers/bootstrap-install-secrets.sh stage
```

## setup-op-service-account.sh

Installs the nixerator 1Password service-account token at
`~/.config/op/service-account-token` with `0600` perms. After this runs once
on a host, `render-secrets`, `render-secrets-bootstrap.sh`, and the justfile
recipes all run with no biometric prompts.

**Prerequisites**: Nix with flakes. The default path (preferred) needs
1Password CLI signed in (`op signin`) and read access to the item
`secrets.json.tpl`'s `onepassword.serviceAccountToken` points at. The helper
extracts that `op://` reference from the template itself (rather than
hardcoding its own copy) and does one `op read`, triggering one
desktop-biometric prompt.

```bash
# Recommended -- fetch the SA token from your Personal vault:
op signin
./extras/helpers/setup-op-service-account.sh

# Alternative inputs if no desktop 1Password on this host:
./extras/helpers/setup-op-service-account.sh --manual           # interactive paste
./extras/helpers/setup-op-service-account.sh < /path/to/token   # from file
OP_TOKEN=ops_... ./extras/helpers/setup-op-service-account.sh   # from env

# Override the source ref (e.g. token moved to a different vault):
OP_TOKEN_REF=op://Vault/Item/field ./extras/helpers/setup-op-service-account.sh
```

Idempotent: if the existing token matches the input, the helper just repairs
perms and exits success. Refuses to replace a different existing token unless
`--force`. Refuses any input that doesn't start with `ops_`.

**Token rotation**: don't run this script by hand for a rotation — use
`just rotate-op-token` (below). Rotating just the token value is
straightforward with this script alone (regenerate in 1Password, update the
item, `--force` on each host), but a full SA regeneration also needs the
render-secrets/op-toggle sequence the rotate script automates; doing it by
hand is exactly what caused a multi-hour outage the first time.

**Live-USB use** (writes from root into the target user's home, before
`nixos-install`):

```bash
sudo ./extras/helpers/setup-op-service-account.sh \
    --dest /home/dustin/.config/op/service-account-token
```

The `bootstrap-install-secrets.sh stage` subcommand wraps this for you
along with the corresponding secrets render.

## rotate-op-service-account.sh

Walks through rotating (or fully regenerating) the nixerator 1Password
service account, end to end, on the host you run it from. This exists
because rotating by hand is failure-prone in a specific, non-obvious way:

- The token has to agree in three places: the SA's own vault grants
  (`nixerator` + `automation`), the 1Password item `secrets.json.tpl` /
  `setup-op-service-account.sh` read from, and the local file at
  `~/.config/op/service-account-token` on this host.
- `op-toggle`'s "back to service-account" path reads its token from the
  *rendered* `secrets.json`, not that local file. Until you've rendered at
  least once with an **explicit** token override, a successful rotation
  still looks broken — every command keeps re-loading the stale, dead
  token baked into the old render, and the error ("Service Account
  Deleted") gives no hint that the fix already worked.
- The nastiest variant is **drift** between the 1Password item and the local
  file: update one but not the other (easy across several rotations) and
  op-toggle / `push-secrets` read the dead token forever, silently. The
  script now writes the token to both itself and self-checks the op-toggle
  path, so this can't pass unnoticed.

```bash
just rotate-op-token             # op read (default, preferred)
just rotate-op-token --manual    # interactive paste
# or directly:
./extras/helpers/rotate-op-service-account.sh
```

What it does:

1. Prints the manual 1Password steps (rotate/regenerate the SA, confirm
   both vault grants) and waits for Enter. You no longer update the
   credential item by hand — step 3 does it.
2. Installs the token locally via `setup-op-service-account.sh --force`.
3. Writes that same token into the 1Password item the template reads from,
   using your desktop session (one biometric prompt) — a blind copy, so the
   value never hits stdout. Keeps the item and the local file in lockstep.
   Warns (and prints the manual `op item edit` one-liner) if the desktop
   session isn't signed in or lacks write access.
4. Renders `secrets.json` with `OP_SERVICE_ACCOUNT_TOKEN` set explicitly
   from the just-installed file — bypassing `op-toggle` entirely, so the
   fresh token is what actually lands in the render.
5. Verifies with `op whoami` / `op vault list` (metadata only, never prints
   the token), warns if any secrets.json field known to need the
   `automation` vault came back empty, and runs a bare `render-secrets
   --check` (the op-toggle path) to confirm the token embedded in
   `secrets.json` authenticates. If it doesn't, the rotation **exits
   non-zero** with the exact `op item edit` fix — the item still holds the
   wrong token. On success it prints (but does not run) the
   `just push-secrets <hosts>` command for the rest of the fleet.

If a full SA regeneration produced a *new* 1Password item (not just a new
token value in the existing item), update `secrets.json.tpl`'s
`onepassword.serviceAccountToken` reference first — the script re-reads the
template on each run, so both it and `setup-op-service-account.sh` pick up
the new item automatically once the template is updated.

## render-secrets-bootstrap.sh

Renders `~/.config/nixos-secrets/secrets.json` from `secrets.json.tpl` via
`op inject` on a fresh machine, BEFORE the first rebuild lands and puts
`render-secrets` on PATH. Uses `nix-shell` to pull the 1Password CLI without
requiring it pre-installed.

**Prerequisites**: Nix with flakes; read access to the `nixerator` 1Password
vault via either a service-account token at `~/.config/op/service-account-token`
(0600, auto-sourced — recommended) OR an active desktop biometric session
(`op signin`).

```bash
cd nixerator
./extras/helpers/render-secrets-bootstrap.sh
sudo nixos-rebuild switch --impure --flake .#$(hostname)
```

**When NOT to use**: after the first rebuild lands on a host. From that point
on, `render-secrets` (and `just render-secrets` / `just push-secrets <host>` /
`just check-secrets`) is on PATH and is the canonical entry point — the
bootstrap helper is duplicate behaviour.

Atomic write: renders to a tempfile inside `~/.config/nixos-secrets/` (perms
`0700`) then `mv -f`'s into place. Partial `op inject` failure or SIGINT
leaves any existing live file untouched.

**Live-USB use** (writes from root into the target user's home, before
`nixos-install`):

```bash
sudo ./extras/helpers/render-secrets-bootstrap.sh \
    --dest /home/dustin/.config/nixos-secrets/secrets.json
```

The `bootstrap-install-secrets.sh stage` subcommand wraps this for you
along with the corresponding SA-token install.

## fetch-okular-signatures.sh

Fetches the Okular signature + initials PNGs from the nixerator 1Password
vault (Document items `okular-signature` + `okular-initials`) and writes
them to `~/.kde/share/icons/{signature,initials}.png` where Okular's
signature-stamp picker looks for them.

**Prerequisites**: `op` (1Password CLI) on PATH (enabled via
`apps.gui.one-password` on this host). SA token at
`~/.config/op/service-account-token` (auto-sourced; install with
`just setup-op-token`) — zero biometric prompts in that case. Falls back
to desktop biometric session if no SA token.

```bash
just fetch-signatures     # alias: just fs
# or directly:
./extras/helpers/fetch-okular-signatures.sh
```

One-time per host (after `just setup-op-token`). Re-run only if you ever
rotate the document in 1Password. Atomic write: renders to a tempfile
inside `~/.kde/share/icons/` then `mv -f`'s into place.
