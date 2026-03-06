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

## setup-git-crypt.sh

Sets up git-crypt encryption on a new system. Uses `nix-shell` to auto-provide all tools.

**Prerequisites**: Nix with flakes, encryption key at `~/.ssh/nixerator-git-crypt-key` (copy from source machine, `chmod 600`).

```bash
cd nixerator
./extras/helpers/setup-git-crypt.sh
```

Checks that git-crypt is installed and the key exists with correct permissions (600). Then unlocks the repository and verifies encrypted files are readable.

**Troubleshooting**:
- Key not found  -- copy from source machine to `~/.ssh/nixerator-git-crypt-key`
- Slow first run  -- nix-shell downloading packages (cached after)
- Files still binary  -- `git-crypt unlock ~/.ssh/nixerator-git-crypt-key` manually
