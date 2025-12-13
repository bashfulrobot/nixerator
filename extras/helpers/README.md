# Helper Scripts

## setup-git-crypt.sh

Sets up git-crypt encryption for the nixerator repository on a new system.

**The script uses nix-shell to automatically provide all required tools** (git-crypt, git, coreutils, file, gnugrep), so you don't need to install anything manually!

### Prerequisites

1. **Nix must be installed with flakes enabled** (already the case for NixOS users)

2. **The encryption key must be copied to the new system:**
   ```bash
   # From your source machine, copy the key:
   scp ~/.ssh/nixerator-git-crypt new-machine:~/.ssh/

   # On the new machine, secure it:
   chmod 600 ~/.ssh/nixerator-git-crypt
   ```

### Usage

After cloning the repository on a new system:

```bash
cd nixerator
./extras/helpers/setup-git-crypt.sh
```

The script will:
- ✓ Verify git-crypt is installed
- ✓ Check the encryption key exists at `~/.ssh/nixerator-git-crypt`
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
- Copy the key from your source machine to `~/.ssh/nixerator-git-crypt`

**Script is slow on first run**
- nix-shell is downloading the required packages (git-crypt, git, etc.)
- Subsequent runs will be instant as packages are cached

**Files still show as binary**
- Run `git-crypt unlock ~/.ssh/nixerator-git-crypt` manually
- Check key permissions: `ls -l ~/.ssh/nixerator-git-crypt` (should be `-rw-------`)
