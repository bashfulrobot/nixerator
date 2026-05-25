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
1Password CLI signed in (`op signin`) and Personal vault read access. The
helper does `op read op://Personal/<item>/credential` to fetch the SA token
once, triggering one desktop-biometric prompt.

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

**Token rotation**: regenerate the SA in 1Password, update the Personal
vault item, then re-run with `--force` on each host.

**Live-USB use** (writes from root into the target user's home, before
`nixos-install`):

```bash
sudo ./extras/helpers/setup-op-service-account.sh \
    --dest /home/dustin/.config/op/service-account-token
```

The `bootstrap-install-secrets.sh stage` subcommand wraps this for you
along with the corresponding secrets render.

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
bootstrap helper is duplicate behaviour. The bootstrap is also unnecessary if
you're happy to rebuild against the git-crypt fallback first and migrate
later (see `setup-git-crypt.sh`).

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

## setup-git-crypt.sh

Sets up git-crypt encryption on a new system. Uses `nix-shell` to auto-provide all tools.

**Prerequisites**: Nix with flakes, encryption key at `~/.ssh/nixerator-git-crypt-key` (copy from source machine, `chmod 600`).

```bash
cd nixerator
./extras/helpers/setup-git-crypt.sh
```

Checks that git-crypt is installed and the key exists with correct permissions (600). Then unlocks the repository and verifies encrypted files are readable.

**Troubleshooting**:

- Key not found -- copy from source machine to `~/.ssh/nixerator-git-crypt-key`
- Slow first run -- nix-shell downloading packages (cached after)
- Files still binary -- `git-crypt unlock ~/.ssh/nixerator-git-crypt-key` manually
