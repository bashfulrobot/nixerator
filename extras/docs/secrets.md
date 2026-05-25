# Secrets Management

Nix-eval secrets are read at flake-eval time from one of two sources, in this
order:

1. **Preferred**: `~/.config/nixos-secrets/secrets.json` (perms `0600`, parent
   dir `0700`) — rendered from `secrets.json.tpl` + 1Password via the
   `render-secrets` helper.
2. **Fallback**: `secrets/secrets.json` in the repo, git-crypt'd at rest.

The flake picks the first one whose file exists. Both paths produce identical
JSON; modules consume `secrets.*` the same way regardless of source. The
fallback exists so a fresh machine can `git-crypt unlock` and rebuild without
ever touching 1Password (`render-secrets` only lands on PATH after the first
successful rebuild — see "Fresh machine bootstrap" below). The fallback is
expected to be removed once the 1Password flow is proven on every host (see
the `FALLBACK SCAFFOLDING` block in `flake.nix`).

The preferred path never enters the Nix store as a flake input (read via a
string path, not a Nix path literal), and is on Claude Code's Read
`permissions.deny` so AI tools scoped to the repo working directory can't read
it. The fallback path IS in-store at eval time (Nix copies the flake source)
— that's the trade-off the legacy git-crypt'd flow always carried.

The deny list intentionally only blocks the Read tool, not enumerated Bash
viewers (`cat`, `bat`, `jq`, `head`, `tail`, …). Trying to enumerate every
shell command that can read a file is a losing game — `grep`, `rg`, `awk`,
`python`, `bash -c '...'`, `tar`, and a dozen others would all need entries
and the list would still leak. The Read fence is the real boundary; the rest
of the threat model relies on agents using the Read tool for file access (which
they do by default).

## One-time setup (per host)

Hosts split into two roles:

| Role | Hosts | Has 1Password CLI? | Renders secrets? |
|------|-------|--------------------|------------------|
| Desktop | donkeykong, qbert | Yes | Yes (locally, plus `--push` to peers) |
| Headless | srv | No | No — receives the file via `scp` from a desktop |

### Authentication: service account vs. desktop biometric

`render-secrets` accepts two auth modes. It picks automatically:

| Mode | Trigger | Biometric prompts |
|------|---------|--------------------|
| Service account (preferred) | `OP_SERVICE_ACCOUNT_TOKEN` env var set, OR `~/.config/op/service-account-token` file exists with `0600` perms | **Zero**, ever |
| Desktop biometric | Neither of the above; falls through to whatever `op` does interactively | Per the 1Password app's CLI integration settings |

Service-account setup (recommended — aligns with 1Password's own guidance to
use least-privilege automation credentials):

1. **One-time, per service account** (web UI): in the 1Password admin web
   UI, create a service account, scope it **read-only** on the `nixerator`
   vault. Save the `ops_…` token to a 1Password item in your Personal vault
   (so you can recover it from any logged-in host).
2. **One-time, per host**: run the setup helper. It uses `op read` to fetch
   the token from your Personal vault (one desktop-biometric prompt) and
   atomically installs it at `~/.config/op/service-account-token` with
   `0600` perms:

   ```bash
   op signin                                              # one biometric
   ./extras/helpers/setup-op-service-account.sh           # fetches via op read
   ```

   Alternative inputs if you don't have desktop 1Password on this host:

   ```bash
   ./extras/helpers/setup-op-service-account.sh --manual           # interactive paste
   ./extras/helpers/setup-op-service-account.sh < /path/to/token   # from file
   OP_TOKEN=ops_... ./extras/helpers/setup-op-service-account.sh   # from env (CI)
   ```

3. From this point on, `render-secrets` auto-sources the file and exports
   `OP_SERVICE_ACCOUNT_TOKEN` for `op inject`. The path is on Claude Code's
   Read `permissions.deny` so AI tools scoped to the repo can't read it.
   Loose perms (anything except `0600`) cause `render-secrets` to refuse
   with a clear error — token file = vault read access.

### Desktop hosts (donkeykong, qbert)

1. Sign in to 1Password CLI: `op signin` (biometric) — only needed if you
   chose desktop-biometric auth above instead of a service account.
2. Make sure the `nixerator` vault and all 19 items below exist (already true
   if you're the maintainer; the table is here for migration and disaster
   recovery). Item titles, types, and field names are pinned — they must match
   `secrets.json.tpl` exactly:

   | Item | Type | Fields |
   |------|------|--------|
   | `kong-konnect-pat` | API Credential | `credential` |
   | `context7` | API Credential | `credential` |
   | `zai` | API Credential | `credential` |
   | `gemini` | API Credential | `credential` |
   | `snyk` | API Credential | `credential` |
   | `tailscale-caddy-authkey` | API Credential | `credential` |
   | `github-pat` | API Credential | `credential` |
   | `todoist` | API Credential | `credential` |
   | `clay-pin` | Password | `password` |
   | `claudito` | Login | `username` + `password` |
   | `syncthing-gui` | Login | `username` + `password` |
   | `b2-credentials` | Secure Note | `keyID` + `applicationKey` |
   | `restic-password` | Password | `password` |
   | `restic-srv` | Secure Note | `repository` + `region` |
   | `restic-workstation` | Secure Note | `repository` + `region` |
   | `plakar-qbert` | Secure Note | `repository` + `passphrase` |
   | `host-qbert` | Secure Note | `tailscale_ip` + `syncthing_id` |
   | `host-donkeykong` | Secure Note | `tailscale_ip` + `syncthing_id` |
   | `host-srv` | Secure Note | `tailscale_ip` |

3. Render: `render-secrets`
4. (Optional, on first setup) push to peers: `render-secrets --push srv`

The vault is intentionally self-contained: some values (the GitHub PAT, the
b2 creds, syncthing creds, todoist token, restic password) also exist as items
in `Personal`, but `secrets.json.tpl` only references `op://nixerator/…`. This
keeps the eval-secrets set under one access boundary so a future service
account can be granted read-only on just this vault.

### Headless hosts (srv)

srv never calls `op inject`. It relies on a desktop pushing the file:

```bash
# From a desktop:
render-secrets --push srv
```

After that, `sudo nixos-rebuild switch --impure --flake .#srv` (whether run on
srv directly or via `just remote-rebuild srv` from a desktop) reads the same
file.

## Daily workflow

Rebuilds **do not re-render**. They just read the cached file at
`~/.config/nixos-secrets/secrets.json`. You re-render only after rotating a
1Password value.

### Local rebuild (any host)

`just qr` (or `just switch`). Reads whatever is in `~/.config/nixos-secrets/secrets.json`.

### Remote rebuild from a desktop

`just remote-rebuild srv` — SSHes to srv and runs `just qr` there. The target
host reads its own local secrets file; nothing is rendered or pushed in this
recipe.

### Rotation (when a 1Password value changes)

```bash
# 1. Update the value in 1Password (in the nixerator-secrets item).

# 2. Re-render locally:
just render-secrets     # alias: just rs

# 3. Push the new file to any peer that needs it:
just push-secrets srv         # one host          (alias: just ps)
just push-secrets srv qbert   # several hosts

# 4. Rebuild as usual:
just qr                       # local
just remote-rebuild srv       # remote
```

`render-secrets` runs `op inject` and triggers a 1Password biometric prompt.
That's the *only* time you'll see one — rebuilds in between never touch
1Password.

### Drift check

```bash
just check-secrets      # alias: just cs
```

Renders to a tempfile (inside `~/.config/nixos-secrets/`, never `/tmp`) and
diffs against the live file. Exits non-zero on drift. Read-only — does not
overwrite.

### Direct CLI

The justfile recipes are thin wrappers; `render-secrets` is also on PATH:

```bash
render-secrets                       # local render, baked template
render-secrets --push srv [qbert]    # render + push to listed hosts
render-secrets --check               # drift check
render-secrets --tpl ./secrets.json.tpl   # use a different template (must
                                          # be inside a git worktree, not
                                          # a symlink) — for editing the
                                          # template in a feature branch
```

`--push HOST` validates `HOST` against an allow-list (`qbert`, `donkeykong`,
`srv`) before invoking `ssh`/`scp`. The list lives in `render-secrets.sh` and
in the `push-secrets` justfile recipe; keep them in sync when adding hosts.

`--tpl PATH` is the only way to override the baked template path. The old
"silently pick up `$PWD/secrets.json.tpl`" behaviour was removed in favour of
this explicit flag — a hostile `cd` no longer turns into a 1Password vault
exfiltration primitive.

## Schema (rendered file)

```json
{
  "github":     { "accessToken": "..." },
  "kong":       { "kongKonnectPAT": "..." },
  "context7":   { "apiKey": "..." },
  "zai":        { "apiKey": "..." },
  "gemini":     { "apiKey": "..." },
  "snyk":       { "token": "..." },
  "clay":       { "pin": "..." },
  "claudito":   { "username": "...", "password": "..." },
  "syncthing":  { "gui": { "user": "...", "password": "..." } },
  "qbert":      { "tailscale_ip": "...", "syncthing_id": "..." },
  "donkey-kong":{ "tailscale_ip": "...", "syncthing_id": "..." },
  "srv":        { "tailscale_ip": "..." },
  "restic":     { "srv": { ... }, "workstation": { ... } },
  "plakar":     { "qbert": { ... } },
  "tailscale":  { "caddyAuthKey": "..." },
  "todoist_token": "..."
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
| `restic.*` | Restic backups to B2 | `hosts/*/modules.nix` |
| `plakar.qbert.*` | Plakar backups to B2 | `apps/cli/plakar` |
| `gemini.apiKey` | Gemini API (visual-explainer, generate-images skills) | `apps/cli/claude-code` |
| `tailscale.caddyAuthKey` | Caddy auto-issued certs on the tailnet | `system/caddy` |
| `todoist_token` | `td` CLI | `apps/cli/todoist-cli` |

## Accessing in Modules

Unchanged — `secrets` still arrives via `specialArgs`:

```nix
{ secrets, ... }:
{
  config = {
    someService.password = secrets.restic.srv.restic_password;

    # Conditional on secret existence (preferred)
    someOption = lib.optionalAttrs (secrets.kong.kongKonnectPAT or null != null) {
      token = secrets.kong.kongKonnectPAT;
    };
  };
}
```

## git-crypt status (still used)

git-crypt is **still active** for:

- `secrets/secrets.json` — the fallback Nix-eval secrets file (see top of doc;
  used when `~/.config/nixos-secrets/secrets.json` doesn't exist).
- `modules/system/ssh/default.nix`.
- Any other files under `secrets/` (`init.png`, `sg.png`, the YASD export).

New GPG keys added via `git-crypt add-gpg-user`. See `.gitattributes` for the
live encryption list.

## Rolling back to the git-crypt-only flow

The 1Password / `render-secrets` flow is opt-in per host via file presence. To
take a host off the new path and back onto git-crypt:

```bash
# On the host you want to roll back:
rm ~/.config/nixos-secrets/secrets.json
sudo nixos-rebuild switch --impure --flake .#$(hostname)
# Flake eval falls back to secrets/secrets.json (git-crypt'd, must be unlocked).
```

To opt back in: `just render-secrets` (or `just push-secrets <host>` from a
peer). The next rebuild picks the rendered file up automatically.

To remove the fallback entirely once the new flow is proven everywhere, see
the `FALLBACK SCAFFOLDING` comment block in `flake.nix` — it lists the four
files to revert.

## Adding a new secret

1. Decide whether the secret fits an existing `nixerator/<item>` (e.g. an
   additional field on `host-qbert`) or needs its own item. Prefer the
   pattern: API token → `API Credential` with `credential` field; password →
   `Password`; user+pass → `Login`; multi-value config → `Secure Note`.
2. Create or extend the item in the `nixerator` 1Password vault.
3. Edit `secrets.json.tpl` in the repo, add the new key with the matching
   `{{ op://nixerator/<item>/<field> }}` placeholder.
4. `render-secrets` on a desktop.
5. `render-secrets --push <host>` for any peer that needs it.
6. Reference in a module via `secrets.path.to.secret` (no module-side change
   to wiring; secrets flow via `specialArgs`).
7. Commit the template change. Don't commit the rendered JSON — `.gitignore`
   blocks it.

## Fresh machine bootstrap

Two paths — pick based on whether you want the first rebuild on this host to
already use the 1Password flow, or to start on git-crypt and migrate later.

### Path A: git-crypt fallback for bootstrap (simplest)

No 1Password CLI needed for the first rebuild. The flake falls back to
`secrets/secrets.json` automatically.

```bash
nix-shell -p git git-crypt
git clone git@github.com:bashfulrobot/nixerator ~/git/nixerator
cd ~/git/nixerator
git-crypt unlock /path/to/nixerator-git-crypt-key
sudo nixos-rebuild switch --impure --flake .#$(hostname)
```

After the switch lands, `render-secrets` is on PATH. To opt this host into the
1Password flow:

```bash
just render-secrets             # local desktop with 1Password
just push-secrets <thishost>    # OR seed from a peer that already has it
```

The next rebuild on this host picks up the rendered file automatically.

### Path B: render before the first rebuild (1Password from day one)

Use this when you don't want the git-crypt'd values in the store even
transiently, or the host won't have git-crypt access at all. A self-contained
helper renders the file using `nix-shell` to pull `op`, so nothing needs to be
pre-installed beyond Nix.

```bash
nix-shell -p git
git clone git@github.com:bashfulrobot/nixerator ~/git/nixerator
cd ~/git/nixerator
op signin                                          # one-time biometric
./extras/helpers/render-secrets-bootstrap.sh       # renders DEST atomically
sudo nixos-rebuild switch --impure --flake .#$(hostname)
```

After the switch lands, the helper is obsolete on this host — `render-secrets`
on PATH does the same job (plus `--push` / `--check` / `--tpl`).

## Troubleshooting

- **`error: builtins.readFile: ... No such file or directory`** during `nix flake check` / rebuild → both sources are missing. Either run `render-secrets` (or `render-secrets --push <thishost>` from a peer), OR `git-crypt unlock` if you're on a fresh machine and intend to use the git-crypt fallback.
- **`render-secrets: 'op' (1Password CLI) not in PATH`** → host doesn't have 1Password installed. Either enable `apps.gui.one-password` + `apps.cli.render-secrets` for it, or render on a peer and `--push` here.
- **`render-secrets: ~/.config/op/service-account-token perms are NNN, must be 600`** → tighten with `chmod 600 ~/.config/op/service-account-token`. The token grants whatever the SA can read; loose perms = any local process gets vault read access.
- **`"Personal" isn't a vault in this account`** (or similar "not a vault" error) → the service account is scoped to `nixerator`, but the template you're injecting references `op://Personal/…` (or another vault). Either you're on a stale branch (the template was rewritten to use `op://nixerator/…` in PR #83), or you've manually edited the template to reference a vault outside the SA's scope.
- **`authorization prompt dismissed`** when running `op inject` → touch the 1Password unlock prompt within the timeout. Re-run.
- **Drift between 1Password and the rendered file** → `render-secrets --check` to see the diff, then plain `render-secrets` to update.
