# Helper Scripts

## reset-home-permissions.sh

Fixes file permissions on home directory, SSH keys, and GPG keys to ensure proper security and functionality.

### Usage

```bash
# Run as your user (will fix permissions for your home directory)
./extras/helpers/reset-home-permissions.sh

# Or run with sudo (will detect and fix for your user, not root)
sudo ./extras/helpers/reset-home-permissions.sh
```

### What It Fixes

**SSH Directory (`~/.ssh/`):**
- Directory: 700 (rwx------)
- Private keys (id_*, *_rsa, *_ed25519): 600 (rw-------)
- Public keys (*.pub): 644 (rw-r--r--)
- config: 600 (rw-------)
- authorized_keys: 600 (rw-------)
- known_hosts: 644 (rw-r--r--)
- Git-crypt keys: 600 (rw-------)

**GPG Directory (`~/.gnupg/`):**
- Directory: 700 (rwx------)
- All files: 600 (rw-------)
- private-keys-v1.d/: 700 (rwx------)
- Configuration files (gpg.conf, gpg-agent.conf): 600

**Home Directory:**
- Ensures correct ownership (does not change permissions)

### When to Use

Run this script when:
- SSH authentication is failing due to permission errors
- GPG key operations are failing
- After restoring files from backup
- After copying SSH/GPG keys between systems
- SSH complains about "permissions too open"

### Troubleshooting

After running the script, if issues persist:
```bash
# Restart GPG agent
gpgconf --kill gpg-agent

# Restart SSH agent (gcr-ssh-agent)
systemctl --user restart gcr-ssh-agent

# Or log out and log back in for a full refresh
```

## setup-git-crypt.sh

Sets up git-crypt encryption for the nixerator repository on a new system.

**The script uses nix-shell to automatically provide all required tools** (git-crypt, git, coreutils, file, gnugrep), so you don't need to install anything manually!

### Prerequisites

1. **Nix must be installed with flakes enabled** (already the case for NixOS users)

2. **The encryption key must be copied to the new system:**
   ```bash
   # From your source machine, copy the key:
   scp ~/.ssh/nixerator-git-crypt-key new-machine:~/.ssh/

   # On the new machine, secure it:
   chmod 600 ~/.ssh/nixerator-git-crypt-key
   ```

### Usage

After cloning the repository on a new system:

```bash
cd nixerator
./extras/helpers/setup-git-crypt.sh
```

The script will:
- ✓ Verify git-crypt is installed
- ✓ Check the encryption key exists at `~/.ssh/nixerator-git-crypt-key`
- ✓ Verify key permissions are secure (600)
- ✓ Unlock the repository
- ✓ Verify encrypted files are readable

### What Gets Encrypted

Configure encrypted files in `.gitattributes`. Add sensitive files that should be encrypted by git-crypt.

Example encrypted files might include:
- SSH host configurations with IPs and usernames
- API keys and credentials
- Private configuration files

### Troubleshooting

**Error: git-crypt key not found**
- Copy the key from your source machine to `~/.ssh/nixerator-git-crypt-key`

**Script is slow on first run**
- nix-shell is downloading the required packages (git-crypt, git, etc.)
- Subsequent runs will be instant as packages are cached

**Files still show as binary**
- Run `git-crypt unlock ~/.ssh/nixerator-git-crypt-key` manually
- Check key permissions: `ls -l ~/.ssh/nixerator-git-crypt-key` (should be `-rw-------`)
