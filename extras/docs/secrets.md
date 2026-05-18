# Secrets Management

Secrets are sourced via a tmpfs JSON file whose path is passed to Nix in the `NIXERATOR_SECRETS` env var. `just _render-secrets` produces that file, then every `just rebuild` / `just upgrade` variant calls it, exports the path, and `shred`s the file on exit. `flake.nix` reads the path; with the env var unset it falls back to an empty attrset so `nix flake check` works without any secrets context.

## Two render modes (dual-mode, while migrating)

`_render-secrets` tries 1Password first and falls back to git-crypt. Both modes produce the same on-disk shape; consumers see no difference.

1. **1Password (preferred).** `secrets/secrets.json.tpl` is committed and contains `op://Personal/<item>/<field>` locators for every leaf. `op inject` resolves each locator into a real JSON value. Requires `op` installed and `op signin` complete (Touch ID per session). See [`secrets/secrets.json.tpl`](../../secrets/secrets.json.tpl) for the schema.
2. **git-crypt (fallback).** If `op` isn't available or signed in, the recipe copies the git-crypt-decrypted `secrets/secrets.json` verbatim into the same tmpfs path. Requires the repo to be unlocked (GPG access).

This dual-mode setup is intentional: it lets the 1Password infrastructure land on `main` before every host is migrated. Once the user's `Personal` vault is fully populated and every host has used the 1P path at least once, the git-crypt half can be removed in a follow-up PR.

## Schema

```json
{
  "github": { "accessToken": "..." },
  "kong": { "kongKonnectPAT": "..." },
  "context7": { "apiKey": "..." },
  "clay": { "pin": "..." },
  "claudito": { "username": "...", "password": "..." },
  "syncthing": {
    "gui": { "user": "...", "password": "..." }
  },
  "qbert":       { "tailscale_ip": "...", "syncthing_id": "..." },
  "donkey-kong": { "tailscale_ip": "...", "syncthing_id": "..." },
  "srv":         { "tailscale_ip": "..." },
  "restic": {
    "srv":         { "restic_repository": "...", "restic_password": "...", "b2_account_id": "...", "b2_account_key": "...", "region": "..." },
    "workstation": { "restic_repository": "...", "restic_password": "...", "b2_account_id": "...", "b2_account_key": "...", "region": "..." }
  },
  "plakar": {
    "qbert": { "repository": "...", "passphrase": "...", "b2_account_id": "...", "b2_account_key": "..." }
  },
  "gemini": { "apiKey": "..." },
  "snyk":   { "token": "..." },
  "todoist_token": "...",
  "tailscale":     { "caddyAuthKey": "..." },
  "ssh": {
    "hosts": {
      "camino": { "hostname": "...", "user": "..." },
      "budgie": { "hostname": "..." },
      "feral":  { "hostname": "...", "user": "..." },
      "qbert_lan": "...",
      "srv_lan":   "...",
      "dk_lan":    "..."
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
| `restic.*` | Backrest + restic backup to B2 | `hosts/*/modules.nix` |
| `gemini.apiKey` | Gemini API (visual-explainer, generate-images skills) | `apps/cli/claude-code` |
| `ssh.hosts.*` | SSH `matchBlocks` topology | `system/ssh` |

## Daily flow

```bash
just rebuild       # touch ID (if 1P signed out), sudo, rebuild, shred
just qr            # same as above, quiet
```

If `op` is signed in and 1P is fully populated, the 1P path runs. Otherwise the recipe quietly falls back to the git-crypt-decrypted `secrets/secrets.json`.

## Rotation

### 1Password path
```bash
op item edit "Nixerator Kong Konnect" pat=NEW_VALUE
just rebuild
```
Template is unchanged — only the 1P item gets edited.

### git-crypt path
```bash
# repo must be unlocked
$EDITOR secrets/secrets.json
just rebuild
git commit -am "chore(secrets): rotate ..."
```

## Adding a new secret

1. Add a leaf to `secrets/secrets.json.tpl`: `"foo": { "key": "op://Personal/Nixerator Foo/key" }`.
2. Also add the matching leaf to `secrets/secrets.json` (still encrypted via git-crypt) so the fallback path works.
3. Create the 1P item: `op item create --vault=Personal --category=password --title="Nixerator Foo" key=value`.
4. Reference it in a Nix module: `secrets.foo.key`. If the consumer is mandatory, add `or ""` / `lib.mkIf (secrets ? foo)` so `nix flake check` (no env var) still passes.
5. Commit and rebuild.

## Initial setup on a new machine

See [`extras/docs/bootstrap.txt`](./bootstrap.txt) for the full procedure. The short version:

- For the 1P path: install `op`, run `op signin`, then `just rebuild`.
- For the git-crypt fallback: `nix-shell -p git-crypt gnupg`, import the GPG key, `git-crypt unlock`, then `just rebuild`.

Both work; pick whichever is easier on the new host.

## Migrating to 1Password

The 1P import helper turns the current `secrets/secrets.json` into a populated `Personal` vault in a single run:

```bash
eval "$(op signin)"
extras/helpers/import-secrets-to-1password.sh --dry-run | head -20   # sanity check
extras/helpers/import-secrets-to-1password.sh                        # actually create items
op item list --vault=Personal --tags= | grep ^Nixerator              # verify
```

After this, `just _render-secrets` will use the 1P path automatically. Confirm by signing out (`op signout`) and re-running — the recipe should fall back to git-crypt — then signing back in and confirming the 1P path takes over.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `error: no 1Password session and no decrypted secrets/secrets.json available` | Neither mode can produce a rendered file | `eval "$(op signin)"`, or `git-crypt unlock` |
| `op inject: validation failed: secret reference is invalid` | An `op://` URI in the template doesn't match a real 1P item | `op item list --vault=Personal --tags= \| grep Nixerator` to verify item names |
| `nix flake check` fails on `attribute … missing` | Consumer doesn't have an `or` guard | Add `or ""` / `or null` at the call site, or wrap in `lib.mkIf (secrets ? foo)` |
| `git show HEAD:secrets/secrets.json` looks binary | Encrypted, as expected | `git-crypt unlock` to decrypt in-tree |

## AI-leak posture

The committed template (`secrets/secrets.json.tpl`) contains only `op://` locators — safe for AI tools to read. The git-crypt-encrypted `secrets/secrets.json` is binary on disk and unreadable without the GPG key, also safe at rest. Plaintext only ever exists in `/run/user/$UID/nixerator-XXXXXX.json` (mode 600, tmpfs, outside the repo) for the seconds of a rebuild, then shredded. `/nix/store` still bakes values into derived configs — an accepted single-user tradeoff. See [`docs/plans/2026-05-16-1password-secrets-design.md`](../../docs/plans/2026-05-16-1password-secrets-design.md) for the full threat-model table.
