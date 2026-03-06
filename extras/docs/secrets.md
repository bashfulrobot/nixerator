# Secrets Management

git-crypt encrypted secrets in `secrets/secrets.json`, auto-decrypted with GPG key access.

## Structure

```json
{
  "restic": {
    "srv": { "restic_repository": "s3:...", "restic_password": "...", "b2_account_id": "...", "b2_account_key": "...", "region": "us-west-000" }
  },
  "kong": { "kongKonnectPAT": "..." }
}
```

Restic credentials are used by the server backup stack (Backrest + restic).

## Accessing in Modules

```nix
{ secrets, ... }:
{
  config = {
    someService.password = secrets.restic.srv.restic_password;

    # Conditional on secret existence
    someOption = lib.optionalAttrs (secrets.kong.kongKonnectPAT or null != null) {
      token = secrets.kong.kongKonnectPAT;
    };
  };
}
```

## Initial Setup (new machine)

```bash
nix-shell -p git-crypt gnupg
gpg --import /path/to/private-key.asc
cd /path/to/nixerator && git-crypt unlock
```

Or use the helper: `./extras/helpers/setup-git-crypt.sh`

## Adding a New GPG Key

```bash
gpg --armor --export user@email.com > user-public.asc
git-crypt add-gpg-user --trusted user@email.com
git add .git-crypt/ && git commit -m "chore: add GPG key for user@email.com"
```

## Adding New Secrets

1. Edit `secrets/secrets.json` (must be unlocked)
2. Add secret following existing structure
3. Reference in module via `secrets.path.to.secret`
4. Commit (file stays encrypted in git)

## Checking Encryption Status

```bash
git-crypt status
git show HEAD:secrets/secrets.json | head -c 50   # binary = encrypted
```

## Troubleshooting

- **"No such file or directory"** -- repo is locked, run `git-crypt unlock`
- **"decryption failed: No secret key"** -- GPG key not imported or wrong key
