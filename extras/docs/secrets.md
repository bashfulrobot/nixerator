# Secrets Management

Nixerator uses git-crypt to encrypt sensitive configuration.

## Overview

Secrets are stored in `secrets/secrets.json` and encrypted with git-crypt. The file is automatically decrypted when you have access to the GPG key.

## Structure

```json
{
  "restic": {
    "srv": {
      "restic_repository": "s3:s3.us-west-000.backblazeb2.com/bucket-name",
      "restic_password": "...",
      "b2_account_id": "...",
      "b2_account_key": "...",
      "region": "us-west-000"
    }
  },
  "kong": {
    "kongKonnectPAT": "..."
  }
}
```

## Accessing Secrets in Modules

Secrets are available via the `secrets` special argument:

```nix
{ secrets, ... }:

{
  config = {
    # Access nested secrets
    someService.password = secrets.restic.srv.restic_password;

    # Conditional configuration based on secret existence
    someOption = lib.optionalAttrs (secrets.kong.kongKonnectPAT or null != null) {
      token = secrets.kong.kongKonnectPAT;
    };
  };
}
```

The `restic` credentials schema stays unchanged and is still used by the server backup setup, including Backrest tooling layered on top of restic.

Backrest package source reference (nixpkgs):
`https://raw.githubusercontent.com/NixOS/nixpkgs/refs/heads/nixos-unstable/pkgs/by-name/ba/backrest/package.nix`

## Setup

### Initial Setup (new machine)

1. Install git-crypt:

```bash
nix-shell -p git-crypt gnupg
```

2. Import your GPG key:

```bash
gpg --import /path/to/private-key.asc
```

3. Unlock the repository:

```bash
cd /path/to/nixerator
git-crypt unlock
```

### Adding a New GPG Key

```bash
# Export the public key
gpg --armor --export user@email.com > user-public.asc

# On a machine with git-crypt unlocked
git-crypt add-gpg-user --trusted user@email.com
git add .git-crypt/
git commit -m "chore: add GPG key for user@email.com"
```

### Setup Script

Use the helper script at `extras/helpers/setup-git-crypt.sh`:

```bash
./extras/helpers/setup-git-crypt.sh
```

## Adding New Secrets

1. Edit `secrets/secrets.json` (must be unlocked)
2. Add your new secret following the existing structure
3. Reference it in your module via `secrets.path.to.secret`
4. Commit the changes (file remains encrypted in git)

## Checking Encryption Status

```bash
# See which files are encrypted
git-crypt status

# Verify a file is encrypted in git
git show HEAD:secrets/secrets.json | head -c 50
# Should show binary garbage if encrypted
```

## Troubleshooting

### "secrets.json: No such file or directory"

The repository is locked. Run `git-crypt unlock`.

### "gpg: decryption failed: No secret key"

Your GPG key is not imported or the repository was encrypted with a different key.

### Adding Secrets for a New Service

1. Decide on the JSON path (e.g., `newservice.api_key`)
2. Add to `secrets/secrets.json`
3. In your module:

```nix
{ lib, secrets, ... }:

{
  config = lib.mkIf (secrets.newservice.api_key or null != null) {
    services.newservice.apiKey = secrets.newservice.api_key;
  };
}
```
