# Secrets Management

git-crypt encrypted secrets in `secrets/secrets.json`, auto-decrypted with GPG key access.

## Schema

```json
{
  "github": {
    "accessToken": "ghp_..."
  },
  "kong": {
    "kongKonnectPAT": "kpat_..."
  },
  "context7": {
    "apiKey": "..."
  },
  "clay": {
    "pin": "..."
  },
  "claudito": {
    "username": "...",
    "password": "..."
  },
  "syncthing": {
    "gui": {
      "user": "...",
      "password": "..."
    }
  },
  "qbert": {
    "tailscale_ip": "100.x.x.x",
    "syncthing_id": "..."
  },
  "donkey-kong": {
    "tailscale_ip": "100.x.x.x",
    "syncthing_id": "..."
  },
  "restic": {
    "srv": {
      "restic_repository": "s3:...",
      "restic_password": "...",
      "b2_account_id": "...",
      "b2_account_key": "...",
      "region": "us-west-000"
    }
  }
}
```

### Key consumers

| Key | Used by | Module |
|-----|---------|--------|
| `github.accessToken` | Nix flake fetches from private repos | `system/nix` |
| `kong.kongKonnectPAT` | Kong Konnect MCP server auth | `apps/cli/claude-code/cfg/mcp-servers.nix` |
| `context7.apiKey` | Context7 MCP server auth | `apps/cli/claude-code/cfg/mcp-servers.nix` |
| `clay.pin` | Clay server PIN auth | `apps/cli/clay` |
| `claudito.username/password` | Claudito server auth | `server/claudito` |
| `syncthing.gui.*` | Syncthing web UI credentials | `apps/cli/syncthing` |
| `qbert.*` / `donkey-kong.*` | Syncthing peer discovery, remote editing | `apps/cli/syncthing`, `apps/gui/zed` |
| `restic.srv.*` | Backrest + restic backup to B2 | `hosts/srv/modules.nix` |
| `gemini.apiKey` | Gemini API (visual-explainer, generate-images skills) | `apps/cli/claude-code` |

### Rotation

1. Edit `secrets/secrets.json` (repo must be unlocked)
2. Update the relevant value
3. Rebuild (`just qr`) to apply
4. Commit (file stays encrypted in git)

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
