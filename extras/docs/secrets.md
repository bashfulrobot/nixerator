# Secrets Management

All sensitive content lives in the **`nixerator` 1Password vault**. There are
two flavours of consumer:

| Consumer | Source | Cached on disk |
|----------|--------|----------------|
| Nix flake eval (modules, hosts) | Items in the `nixerator` vault rendered via `secrets.json.tpl` + `op inject` | `~/.config/nixos-secrets/secrets.json` (0600) |
| Okular signature stamping | Document items `okular-signature` + `okular-initials` in the `nixerator` vault | `~/.kde/share/icons/{signature,initials}.png` (0644) |

Neither cached file is in the repo, in the Nix store, or available to AI
tooling scoped to the repo working directory (both paths are on Claude
Code's Read `permissions.deny`). The Nix-eval cached file is read at
flake-eval time via a string path (not a Nix path literal) so it never
enters the store as a flake input.

git-crypt is no longer used in this repo. The fallback `secrets/secrets.json`
that bridged the migration was removed in #86; see git history for the
retired flow.

## One-time per-host setup

1. **Install the SA token** (one biometric):
   ```bash
   op signin                # if not already signed in (desktop biometric)
   just setup-op-token      # op read fetches the SA token, installs at
                            # ~/.config/op/service-account-token (0600)
   ```
   After this, every other secrets command on this host is biometric-free.

2. **Render the Nix-eval secrets file**:
   ```bash
   just render-secrets      # writes ~/.config/nixos-secrets/secrets.json
   ```

3. **Fetch the Okular signature PNGs** (only on hosts where you use Okular):
   ```bash
   just fetch-signatures    # writes ~/.kde/share/icons/{signature,initials}.png
   ```

All three are idempotent — safe to re-run any time.

## Daily workflow

Rebuilds **do not re-fetch anything from 1Password.** They read the cached
files directly off disk:

- **Local rebuild**: `just qr` (or `just switch`)
- **Remote rebuild from a desktop**: `just remote-rebuild srv` (or
  `qbert`/`donkeykong`). SSHes to the target and runs `just qr` there;
  the target host reads its own cached file.

## Rotation (when a 1Password value changes)

```bash
# 1. Update the value in the matching nixerator/<item>. See the item table
#    below for which 1P item holds which secret.

# 2. Re-render locally:
just render-secrets          # alias: rs

# 3. Push the new file to any peer that needs it:
just push-secrets srv        # one host           (alias: ps)
just push-secrets srv qbert  # several hosts

# 4. Rebuild as usual:
just qr                      # local
just remote-rebuild srv      # remote
```

Zero biometric prompts for any of this once the SA token is installed.

## Drift check

```bash
just check-secrets           # alias: cs
```

Renders to a tempfile (inside `~/.config/nixos-secrets/`, never `/tmp`) and
diffs against the live cached file. Exits non-zero on drift. Read-only.

## Direct CLI

The justfile recipes are thin wrappers; `render-secrets` is also on PATH:

```bash
render-secrets                       # local render
render-secrets --push srv [qbert]    # render + push to listed hosts
render-secrets --check               # drift check
render-secrets --tpl ./secrets.json.tpl   # use a different template (must be
                                          # inside a git worktree, not a
                                          # symlink) -- for editing the
                                          # template in a feature branch
```

`--push HOST` validates `HOST` against the allow-list (`qbert`, `donkeykong`,
`srv`); the same list is enforced in the `push-secrets` justfile recipe.

## `nixerator` vault items

Names are pinned — they must match `secrets.json.tpl` exactly.

| Item | Type | Fields | Consumed as |
|------|------|--------|-------------|
| `kong-konnect-pat` | API Credential | `credential` | `secrets.kong.kongKonnectPAT` |
| `context7` | API Credential | `credential` | `secrets.context7.apiKey` |
| `zai` | API Credential | `credential` | `secrets.zai.apiKey` |
| `gemini` | API Credential | `credential` | `secrets.gemini.apiKey` |
| `snyk` | API Credential | `credential` | `secrets.snyk.token` |
| `tailscale-caddy-authkey` | API Credential | `credential` | `secrets.tailscale.caddyAuthKey` |
| `github-pat` | API Credential | `credential` | `secrets.github.accessToken` |
| `todoist` | API Credential | `credential` | `secrets.todoist_token` |
| `clay-pin` | Password | `password` | `secrets.clay.pin` |
| `claudito` | Login | `username` + `password` | `secrets.claudito.*` |
| `syncthing-gui` | Login | `username` + `password` | `secrets.syncthing.gui.*` |
| `b2-credentials` | Secure Note | `keyID` + `applicationKey` | `secrets.{restic,plakar}.*.b2_account_*` (shared) |
| `restic-password` | Password | `password` | `secrets.restic.{srv,workstation}.restic_password` (shared) |
| `restic-srv` | Secure Note | `repository` + `region` | `secrets.restic.srv.{restic_repository,region}` |
| `restic-workstation` | Secure Note | `repository` + `region` | `secrets.restic.workstation.{restic_repository,region}` |
| `plakar-qbert` | Secure Note | `repository` + `passphrase` | `secrets.plakar.qbert.{repository,passphrase}` |
| `okular-signature` | Document | `file` | `~/.kde/share/icons/signature.png` (via `just fetch-signatures`) |
| `okular-initials` | Document | `file` | `~/.kde/share/icons/initials.png` (via `just fetch-signatures`) |

Per-host network identity (Tailscale IPs, syncthing peer IDs) is NOT in 1P;
those values live in `settings/globals.nix` under
`hosts.{qbert,donkeykong,srv}` because they're already published in
plaintext docs in this repo and don't grant access on their own.

### Authentication: service account vs. desktop biometric

`render-secrets`, `fetch-okular-signatures.sh`, and
`render-secrets-bootstrap.sh` accept two auth modes. They pick
automatically:

| Mode | Trigger | Biometric prompts |
|------|---------|--------------------|
| Service account (preferred) | `OP_SERVICE_ACCOUNT_TOKEN` env var, OR `~/.config/op/service-account-token` (0600) | **Zero**, ever |
| Desktop biometric | Neither of the above; falls through to interactive `op` | Per the 1Password app's CLI integration settings |

The SA token itself lives in your **Personal** 1Password vault.
`just setup-op-token` uses `op read` to fetch it (one biometric) and
installs it at the canonical path. Read-only access to the `nixerator`
vault is all the SA needs.

## Accessing in modules

`secrets` arrives via `specialArgs`:

```nix
{ secrets, ... }:
{
  config = {
    someService.password = secrets.restic.srv.restic_password;

    # Conditional on secret existence (defensive in case a module is
    # consumed before all values are populated)
    someOption = lib.optionalAttrs (secrets.kong.kongKonnectPAT or null != null) {
      token = secrets.kong.kongKonnectPAT;
    };
  };
}
```

Per-host network identity comes via `globals`:

```nix
{ globals, ... }:
{
  config.someService.peerAddress = globals.hosts.qbert.tailscale_ip;
}
```

## Adding a new secret

1. Decide whether it fits an existing `nixerator/<item>` (e.g. an additional
   field on `restic-srv`) or needs its own item. Prefer the pattern: API
   token → `API Credential` with `credential` field; password → `Password`;
   user+pass → `Login`; multi-value config → `Secure Note`; binary blob →
   `Document`.
2. Create or extend the item in the `nixerator` 1Password vault.
3. Edit `secrets.json.tpl`, add the new key with the matching
   `{{ op://nixerator/<item>/<field> }}` placeholder.
4. `just render-secrets` on a desktop.
5. `just push-secrets <host>` for any peer that needs it.
6. Reference in a module via `secrets.path.to.secret`.
7. Commit the template change.

## Fresh machine bootstrap

See `extras/docs/bootstrap.txt` for the full install guide. The
secrets-related steps:

- **Pre-install** (on the live USB, after `git clone`):
  ```bash
  sudo ./extras/helpers/bootstrap-install-secrets.sh stage
  ```
  Walks you through `op signin`, fetches the SA token, renders secrets into
  `/home/dustin/.config/...` so `nixos-install` can read them.

- **Post-install, before reboot**:
  ```bash
  sudo ./extras/helpers/bootstrap-install-secrets.sh promote
  ```
  Copies staged files into `/mnt/home/dustin/...` and chowns to the install
  user via `nixos-enter`.

- **After first boot**:
  ```bash
  just fetch-signatures        # only if you use Okular on this host
  ```

## Troubleshooting

- **`builtins.readFile: No such file or directory`** during rebuild → the
  rendered file is missing. Run `just render-secrets` (or
  `just push-secrets <thishost>` from a peer).
- **`render-secrets: 'op' (1Password CLI) not in PATH`** → host doesn't have
  1Password installed. Enable `apps.gui.one-password` +
  `apps.cli.render-secrets` on this host, or render on a peer and `--push`
  here.
- **`render-secrets: ~/.config/op/service-account-token perms are NNN, must be 600`**
  → `chmod 600 ~/.config/op/service-account-token`. The token grants vault
  read access; loose perms = any local process can read your nixerator vault.
- **`"Personal" isn't a vault in this account`** under SA mode → you're on a
  stale branch where `secrets.json.tpl` still references `op://Personal/…`;
  rebase onto main.
- **Drift between 1Password and the rendered file** → `just check-secrets`
  to see the diff, then `just render-secrets` to update.
