# Secrets Management

All sensitive content lives in the **`nixerator` 1Password vault**. There are
two flavours of consumer:

| Consumer | Source | Cached on disk |
|----------|--------|----------------|
| Nix flake eval (modules, hosts) | Items in the `nixerator` vault rendered via `secrets.json.tpl` + `op inject` | `~/.config/nixos-secrets/secrets.json` (0600) |
| Okular signature stamping | Document items `okular-signature` + `okular-initials` in the `nixerator` vault | `~/.kde/share/icons/{signature,initials}.png` (0644) |
| gmailctl OAuth client | Login item `gmailctl` (`Client ID` + `Client Secret` fields) in the `nixerator` vault, rendered via `op inject` by `just fetch-gmailctl-creds` | `~/.gmailctl/credentials.json` (0600) |
| homelab git-crypt key | Document item `homelab git-crypt key` in the `nixerator` vault, materialized by `render-secrets` when `~/git/iac` is present (skipped if already on disk) | `~/.config/git-crypt/homelab.key` (0600) |
| SSH + per-repo git-crypt keys | Document items in the `nixerator` vault, materialized by `render-secrets` on workstation hosts (skipped if already on disk) | `~/.ssh/*` (0600 private / 0644 public) |

Neither cached file is in the repo, in the Nix store, or available to AI
tooling scoped to the repo working directory (both paths are on Claude
Code's Read `permissions.deny`). The Nix-eval cached file is read at
flake-eval time via a string path (not a Nix path literal) so it never
enters the store as a flake input.

git-crypt is no longer used in this repo. The fallback `secrets/secrets.json`
that bridged the migration was removed in #86; see git history for the
retired flow.

## Hard boundary for AI assistants (Claude Code)

**Never read rendered secret VALUES — from the secrets file or from 1Password.**
This is a non-negotiable rule, not a preference: a secret value read into the
agent's context leaks into the model and can be sent off-site.

- **Never** read `~/.config/nixos-secrets/secrets.json` or anything under
  `~/.config/op/` — both are on Claude Code's Read `permissions.deny`. To inspect
  the schema, read `secrets.json.tpl` (placeholders only).
- **Never** surface a secret value via 1Password: no `op read` of a credential,
  no `op item get … --reveal`, no echoing/printing a field value — not even a
  prefix, suffix, or length. Partial exposure is still exposure.
- **Allowed — references/metadata only:** item titles, field labels, vault names,
  `op://` paths, and whether an item/field exists.
- **Allowed — placeholders:** create items/fields with a dummy value
  (`op item create … credential="REPLACE_ME"`) for the user to fill in.
- **Allowed — blind move:** pipe a value between fields without displaying it
  (`op item edit dest field="$(op read 'op://src/item/field')"`) — the value
  passes through the subshell but never reaches stdout.
- **Verifying a secret landed:** do NOT read it back. Run it through the normal
  tooling (`just render-secrets` / `just check-secrets`) and trust the exit
  status, or check existence/non-emptiness by means that never print the value
  (e.g. transform the value to a present/absent boolean in `jq` before printing).

This mirrors the identical global rule in `~/.claude/CLAUDE.md`.

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

## Materialized host files

Besides the rendered `secrets.json`, `render-secrets` restores a small set of
**document-backed files** from the `nixerator` vault straight onto the host:
binary secrets that have to live at a specific path, like a git-crypt key. The
list is the `MATERIALIZE` table at the top of
`modules/apps/cli/render-secrets/render-secrets.sh`.

For each entry, `render-secrets`:

- skips it entirely if the entry's **guard** fails. A guard is a path that must
  exist (e.g. the consuming repo) or a `host:h1,h2` list of hostnames, so a file
  only lands where it belongs;
- **skips the fetch but fixes permissions** if the destination already exists
  (it never clobbers a key already on disk);
- otherwise fetches the 1Password Document and writes it atomically with the
  declared mode.

These files are host-local. Most are **not** copied by `--push`; they are
restored on a plain `just render-secrets`, so a fresh host gets them as part
of the normal secrets step. Files in the `PUSH_ALONGSIDE` table (below) are
the exception — they are also pushed alongside `secrets.json` so remote hosts
have them at Nix eval time without a manual `scp`.

Current MATERIALIZE entries:

| Document item | Restored to | Mode | Guard |
|---------------|-------------|------|-------|
| `homelab git-crypt key` | `~/.config/git-crypt/homelab.key` | 0600 | `~/git/iac` present |
| `id_ed25519`, `id_ed25519_np`, `id_rsa` | `~/.ssh/<name>` | 0600 | workstation hosts |
| `id_ed25519.pub`, `id_rsa.pub`, `id_rsa_np.pub` | `~/.ssh/<name>` | 0644 | workstation hosts |
| `mixerator-`, `nixcfg-`, `nixerator-`, `talos-vms-git-crypt-key` | `~/.ssh/<name>` | 0600 | workstation hosts |
| `incus-ui.crt` | `~/.config/incus/client.crt` | 0644 | all hosts |
| `incus-ui.pfx` | `~/.config/incus/client.pfx` | 0600 | workstation hosts |

Current PUSH_ALONGSIDE entries (also pushed to remotes by `--push`):

| Local path | Remote mode | Why |
|------------|-------------|-----|
| `~/.config/incus/client.crt` | 0644 | Needed at Nix eval time on every Incus host so `builtins.readFile` in the incus module can populate the preseed trust store |

"Workstation hosts" are those with `archetypes.workstation.enable = true`
(donkeykong, nixerator, qbert), matched by the `host:` guard. The pure server
never receives the SSH or per-repo git-crypt keys.

After the homelab key lands, unlock the repo once so its state decrypts:

```bash
cd ~/git/iac && git-crypt unlock ~/.config/git-crypt/homelab.key
```

To add another (an SSH key, or another repo's git-crypt key): upload the file as
a Document item to the `nixerator` vault, then add a `MATERIALIZE` row
`"<item title>|<dest>|<file mode>|<dir mode>|<guard or empty>"`.

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
| `Tableau PAT` | API Credential | `hostname`, `Site Name`, `username`, `credential` | `secrets.tableau.{server,siteName,patName,patValue}` (self-hosted/local Tableau MCP against Kong's Tableau Cloud site; injected as `SERVER`/`SITE_NAME`/`PAT_NAME`/`PAT_VALUE` by the claude-code module) |
| `aha` | API Credential | `credential` | `secrets.aha.apiToken` (injected as `AHA_API_TOKEN` by the claude-code module for the `aha` skill) |
| `wave` | API Credential | `credential` | `secrets.wave.fullAccessToken` (injected as `WAVE_FULL_ACCESS_TOKEN` by the claude-code module for the `wave-invoicing` skill; Wave Full Access Token — personal-use bearer, no OAuth) |
| `context7` | API Credential | `credential` | `secrets.context7.apiKey` |
| `zai` | API Credential | `credential` | `secrets.zai.apiKey` |
| `gemini` | API Credential | `credential` | `secrets.gemini.apiKey` |
| `snyk` | API Credential | `credential` | `secrets.snyk.token` |
| `tailscale-caddy-authkey` | API Credential | `credential` | `secrets.tailscale.caddyAuthKey` |
| `github-pat` | API Credential | `credential` | `secrets.github.accessToken` |
| `todoist` | API Credential | `credential` | `secrets.todoist_token` |
| `cloudflare-ddns` | API Credential | `credential` | `secrets.cloudflareDdns.apiToken` (scope: `Zone / DNS / Edit` on the target zones only) |
| `syncthing-gui` | Login | `username` + `password` | `secrets.syncthing.gui.*` |
| `b2-credentials` | Secure Note | `keyID` + `applicationKey` | `secrets.{restic,plakar}.*.b2_account_*` (shared) |
| `restic-password` | Password | `password` | `secrets.restic.{srv,workstation}.restic_password` (shared) |
| `restic-srv` | Secure Note | `repository` + `region` | `secrets.restic.srv.{restic_repository,region}` |
| `restic-workstation` | Secure Note | `repository` + `region` | `secrets.restic.workstation.{restic_repository,region}` |
| `plakar-qbert` | Secure Note | `repository` + `passphrase` | `secrets.plakar.qbert.{repository,passphrase}` |
| `okular-signature` | Document | `file` | `~/.kde/share/icons/signature.png` (via `just fetch-signatures`) |
| `okular-initials` | Document | `file` | `~/.kde/share/icons/initials.png` (via `just fetch-signatures`) |
| `homelab git-crypt key` | Document | `file` | `~/.config/git-crypt/homelab.key` (via `render-secrets`) |
| `id_ed25519{,_np,.pub}`, `id_rsa{,.pub}`, `id_rsa_np.pub` | Document | `file` | `~/.ssh/<name>` on workstation hosts (via `render-secrets`) |
| `mixerator-`, `nixcfg-`, `nixerator-`, `talos-vms-git-crypt-key` | Document | `file` | `~/.ssh/<name>` on workstation hosts (via `render-secrets`) |
| `gmailctl` | Login | `Client ID` + `Client Secret` | `~/.gmailctl/credentials.json` (via `just fetch-gmailctl-creds`, which `op inject`s the two fields into a Desktop-app credentials.json template). Rendered straight to disk, **not** in `secrets.json` — keeps the client secret out of the Nix store. `gmailctl init` then writes `~/.gmailctl/token.json` locally. |
| `incus-ui.crt` | Document | `file` | `~/.config/incus/client.crt` on all hosts (via `render-secrets` MATERIALIZE, 0644). Public certificate read by the Incus module via `builtins.readFile` at Nix eval time and injected into the preseed trust store. All Incus hosts; safe to be world-readable. |
| `incus-ui.pfx` | Document | `file` | `~/.config/incus/client.pfx` on workstations (via `render-secrets` MATERIALIZE, 0600). PKCS12 bundle with private key; import into a browser to authenticate against any Incus web UI. Workstations only — srv is headless. |

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
