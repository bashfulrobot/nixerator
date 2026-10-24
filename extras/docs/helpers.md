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

## fetch-okular-signatures.sh

Fetches the Okular signature + initials PNGs from the nixerator 1Password
vault (Document items `okular-signature` + `okular-initials`) and writes
them to `~/.kde/share/icons/{signature,initials}.png` where Okular's
signature-stamp picker looks for them.

**Prerequisites**: `op` (1Password CLI) on PATH (enabled via
`apps.gui.one-password` on this host) and the 1Password desktop app
unlocked.

```bash
just fetch-signatures     # alias: just fs
# or directly:
./extras/helpers/fetch-okular-signatures.sh
```

One-time per host. Re-run only if you ever rotate the document in
1Password. Atomic write: renders to a tempfile inside `~/.kde/share/icons/`
then `mv -f`'s into place.

## bootstrap-install-gopass.sh

Live-USB secrets bootstrap for a fresh NixOS install, with no 1Password service
account. `stage` streams the secauto GPG key and the encrypted store from an
existing host over SSH (`SOURCE_SSH=user@host`) and renders `secrets.json` from
gopass. `promote` copies the staged files onto `/mnt` after `nixos-install`. SSH
and git-crypt keys come back after first boot with `just render-secrets-op`. Not
yet run on a real install: try it in a VM first. See `bootstrap.txt` and
`secrets-roadmap.md`.

## import-op-to-gopass.sh

Copies 1Password values into the secauto gopass store (run on qbert). Flags:
`--update` overwrites a changed entry, `--check` reports drift by entry name,
`--mirror`, `--documents`, `--dry-run`. Run through `just import-secrets-to-gopass`
and `just check-snapshot`. Uses the 1Password desktop app. Prints names only, never
a value.

## fetch-gmailctl-credentials.sh

Writes the gmailctl OAuth client to `~/.gmailctl/credentials.json` from the gopass
entries `nixerator/gmailctl/client-id` and `client-secret` (`just fetch-gmailctl-creds`).
