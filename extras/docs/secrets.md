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
| srv `server.nanoclaw` | `nanoclaw-*` items in the `nixerator` vault, via `secrets.json` and `installValue`. See `extras/docs/nanoclaw/README.md` | `/run/nanoclaw-secrets/<name>` (tmpfs, root 0400) |

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

The global rule in `~/.claude/CLAUDE.md` states this prohibition inline and
points here for the mechanics above.

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

## Rotating the service account

Don't rotate the SA token by hand — use `just rotate-op-token` (alias
`rot`). Rotating it manually is failure-prone: the token has to agree
across the SA's own vault grants, the 1Password item the template reads
from, and the local file on each host, and `op-toggle` reads its
service-account fallback from the *rendered* `secrets.json` rather than
that local file — so a stale render makes a successful rotation look like
it silently didn't take (you'll see `(403) Forbidden (Service Account
Deleted)` even though the new token is fine).

```bash
just rotate-op-token             # walks the full sequence, one host
just rotate-op-token --manual    # paste the token instead of op read
```

The script writes the new token to **both** the local file and the
1Password item (step 3, via your desktop session — one biometric prompt),
so the two can't drift. That drift is the classic silent failure: the file
gets the new token but the item keeps the old one, and every op-toggle /
`push-secrets` call then reads the dead token with nothing to warn you. To
catch it regardless, step 5 runs a bare `render-secrets --check` (the
op-toggle path) and **fails the rotation** if the embedded token doesn't
authenticate, printing the exact `op item edit` one-liner to fix it.

See `extras/docs/helpers.md`'s `rotate-op-service-account.sh` section for
the full step-by-step. It prints — but does not run — the `push-secrets`
command for the rest of the fleet; run that yourself once you're happy with
the verification output.

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
| `feral-arr` | `~/.ssh/feral-arr` | 0600 | srv + workstation hosts |
| `feral-arr.pub` | `~/.ssh/feral-arr.pub` | 0644 | srv + workstation hosts |
| `incus-ui.crt` | `~/.config/incus/client.crt` | 0644 | all hosts |
| `incus-ui.pfx` | `~/.config/incus/client.pfx` | 0600 | workstation hosts |
| `filebot-license` | `~/.local/share/filebot/data/.license` | 0600 | all hosts (unused outside srv) |
| `snowflake-connections-toml` | `~/.snowflake/connections.toml` | 0600 | workstation hosts |

Current PUSH_ALONGSIDE entries (also pushed to remotes by `--push`):

| Local path | Remote mode | Why |
|------------|-------------|-----|
| `~/.config/incus/client.crt` | 0644 | Needed at Nix eval time on every Incus host so `builtins.readFile` in the incus module can populate the preseed trust store |
| `~/.local/share/filebot/data/.license` | 0600 | srv is headless (no 1Password CLI); the license only reaches it via `--push` from a workstation that materialized it locally |

"Workstation hosts" are those with `archetypes.workstation.enable = true`
(nixerator, qbert), matched by the `host:` guard. The pure server
never receives the identity SSH keys or per-repo git-crypt keys. The one
exception is `feral-arr`/`feral-arr.pub`: a single-purpose key for the
darkstar arr download-sync CronJob's rsync from the feralhosting seedbox,
explicitly scoped to srv as well (srv is the dlm/dltv revert path and where
the rsync is exercised by hand).

After the homelab key lands, unlock the repo once so its state decrypts:

```bash
cd ~/git/iac && git-crypt unlock ~/.config/git-crypt/homelab.key
```

To add another (an SSH key, or another repo's git-crypt key): upload the file as
a Document item to the `nixerator` vault, then add a `MATERIALIZE` row
`"<item title>|<dest>|<file mode>|<dir mode>|<guard or empty>"`.

**A MATERIALIZE row only takes effect once it reaches the deployed script.** The
row is baked into the `render-secrets` binary at build time, so the commit adding
it has to land on `main` (or whatever branch you rebuild from) and the host has
to rebuild before the entry exists. A row sitting on an unmerged or unpushed
branch renders nothing: no error, the entry is just absent from the output. To
confirm a row is live, run `render-secrets` and look for the file in its output,
or grep the source `render-secrets.sh` or the wrapped payload. Don't grep
`bin/render-secrets` itself; `wrapProgram` leaves only a PATH-prefixing stub
there, so it always looks empty (see `.claude/docs/conventions.md`).

## Daily workflow

Rebuilds **do not re-fetch anything from 1Password.** They read the cached
files directly off disk:

- **Local rebuild**: `just qr` (or `just switch`)
- **Remote rebuild from a desktop**: `just remote-rebuild srv` (or
  `qbert`). SSHes to the target and runs `just qr` there;
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

`--push HOST` validates `HOST` against the allow-list (`qbert`, `srv`); the same list is enforced in the `push-secrets` justfile recipe.

## `nixerator` vault items

Names are pinned — they must match `secrets.json.tpl` exactly.

| Item | Type | Fields | Consumed as |
|------|------|--------|-------------|
| `kong-konnect-pat` (now in the `automation` vault) | API Credential | `lab-pat-2026-06` | `secrets.kong.kongKonnectPAT` |
| `Tableau-PAT` (now in the `automation` vault) | API Credential | `hostname` (full `https://` origin, not a bare host), `Site-Name`, `username`, `credential` | `secrets.tableau.{server,siteName,patName,patValue}` (self-hosted/local Tableau MCP against Kong's Tableau Cloud site; injected as `SERVER`/`SITE_NAME`/`PAT_NAME`/`PAT_VALUE` by the claude-code module; workstation-only, see `serverProfile` gate in `mcp-servers.nix`) |
| `aha` | API Credential | `credential` | `secrets.aha.apiToken` (injected as `AHA_API_TOKEN` by the claude-code module for the `aha` skill) |
| `wave` | API Credential | `credential` | `secrets.wave.fullAccessToken` (injected as `WAVE_FULL_ACCESS_TOKEN` by the claude-code module for the `wave-invoicing` skill; Wave Full Access Token — personal-use bearer, no OAuth) |
| `forgejo-api` | API Credential | `token` | `.forgejo.apiToken` in the rendered blob, read at **runtime** (never through the Nix store): the fish module exports it as `FORGEJO_TOKEN` for skills that curl the Forgejo (`git.srvrs.co`) REST API, and the git module renders `~/.config/tea/config.yml` for the `tea` CLI. High-privilege token — skills using it default read-only and gate writes. |
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
| `feral-arr`, `feral-arr.pub` | Document | `file` | `~/.ssh/feral-arr{,.pub}` on srv + workstation hosts (via `render-secrets`). Single-purpose key for darkstar's arr download-sync CronJob rsync from the feralhosting seedbox; also consumed in-cluster by homelab's `just workloads::create-arr-ssh-secret`, which reads the same 1Password document. |
| `gmailctl` | Login | `Client ID` + `Client Secret` | `~/.gmailctl/credentials.json` (via `just fetch-gmailctl-creds`, which `op inject`s the two fields into a Desktop-app credentials.json template). Rendered straight to disk, **not** in `secrets.json` — keeps the client secret out of the Nix store. `gmailctl init` then writes `~/.gmailctl/token.json` locally. |
| `incus-ui.crt` | Document | `file` | `~/.config/incus/client.crt` on all hosts (via `render-secrets` MATERIALIZE, 0644). Public certificate read by the Incus module via `builtins.readFile` at Nix eval time and injected into the preseed trust store. All Incus hosts; safe to be world-readable. |
| `incus-ui.pfx` | Document | `file` | `~/.config/incus/client.pfx` on workstations (via `render-secrets` MATERIALIZE, 0600). PKCS12 bundle with private key; import into a browser to authenticate against any Incus web UI. Workstations only — srv is headless. |
| `filebot-license` | Document | `file` | `~/.local/share/filebot/data/.license` on srv (via `render-secrets` MATERIALIZE + PUSH_ALONGSIDE, 0600). FileBot lifetime license (`.psm`) used by `dlm`/`dltv` (`modules/apps/cli/media-rename`) to rename/organize media. Materializes on any host running `render-secrets` but is only meaningful on srv, which gets it via `just push-secrets srv`. |
| `snowflake-connections-toml` | Document | `file` | `~/.snowflake/connections.toml` on workstation hosts (via `render-secrets` MATERIALIZE, 0600). No secret value inside -- auth is externalbrowser (interactive SSO, no password/token) -- just kept out of git because it names the internal Snowflake account locator/role/warehouse/database/schema. Consumed by `apps.cli.snowstorm` (the `snowstorm` Snowflake data-access CLI). |

Per-host network identity (Tailscale IPs, syncthing peer IDs) is NOT in 1P;
those values live in `settings/globals.nix` under
`hosts.{qbert,srv}` because they're already published in
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

## Automation secrets (secauto)

Unattended jobs read their secrets from gopass, not from 1Password. Service-account tokens expire, and `op` falls back to the desktop prompt in any process that lacks the token, so a headless job cannot rely on it. A gopass read needs only the local GPG key: no expiry, no network login.

How it fits together:

- The store is the private repo `bashfulrobot/secauto`. It holds one GPG-encrypted file per secret, plus `.gpg-id`. The decrypting key is never in the repo.
- qbert is the only writer. It commits and pushes from its clone at `~/git/secauto`.
- Reader hosts (srv, the Mac) keep a clone at `~/.local/share/gopass/stores/root`. On NixOS, `apps.cli.secauto-pull` runs `git pull --ff-only` every 15 minutes over a read-only deploy key.
- One passphrase-less GPG key (uid `secauto automation`) decrypts the store on every host. The recovery copy is the 1Password Document `secauto-gpg-key` in the Personal vault, which service accounts cannot read. Open it only to rebuild a host or after losing every other copy.

Setting up a reader host (once):

1. Install `gopass` and `gnupg` (the dev suite on NixOS, `Brewfile.core` on the Mac).
2. Import the key without a passphrase prompt. Without the loopback flags, gpg can open a pinentry to set a passphrase, which would bring the prompt back:
   ```bash
   ssh qbert 'gpg --export-secret-keys --armor <fingerprint>' \
     | gpg --batch --pinentry-mode loopback --passphrase '' --import
   echo '<fingerprint>:6:' | gpg --import-ownertrust
   ```
3. Create a read-only deploy key on the host, then register it from qbert:
   ```bash
   ssh-keygen -t ed25519 -N "" -f ~/.ssh/secauto_deploy
   gh repo deploy-key add <pub file> -R bashfulrobot/secauto -t <host>
   ```
4. Clone the store with `gopass clone git@github.com:bashfulrobot/secauto.git`, setting `GIT_SSH_COMMAND` so it uses the deploy key.
5. Set `apps.cli.secauto-pull.enable = true` for the host and rebuild.

Add or rotate a secret on qbert. Type the value yourself at the prompt (`gopass insert <name>`) so it never enters an AI transcript, then push. Readers pick it up on their next pull. A job that reads at run time (`gopass show -o <name>`) gets the new value on its next run. A service that read the value at startup, or a file an activation script wrote once, keeps the old value until it restarts or the host rebuilds.

Rules for AI assistants: never run `gopass show`, `gopass cat` or `pass show`, and never print the GPG private key. `gopass ls` (names only) is fine.

### Rendering `secrets.json` from gopass

`render-secrets --from gopass` (`just render-secrets-gopass`, alias `rsg`) fills the same `secrets.json.tpl` from the store, so the Nix modules, fish exports and flake guards keep reading the file they already read. No `op`, no service-account token, no desktop prompt, so it runs on srv, in a timer or over SSH.

- `modules/apps/cli/render-secrets/gopass-map.tsv` maps each gopass entry to the `op://` reference the template uses (`aha/credential` ↔ `op://nixerator/aha/credential`). Names and references only. Add a row there when you add a template key.
- A key is left out of the file, never written empty, when its reference is not in the map or its entry is missing or empty. Modules already guard on presence. The stderr list names entries, not values. The 1Password service-account token (`onepassword.serviceAccountToken`) is deliberately unmapped.
- Document-backed files (SSH keys, certificates, `connections.toml`) still restore through `render-secrets` in `op` mode. `--from gopass` skips them.
- `just check-secrets-gopass` (`csg`) compares the live file with a gopass render and names the keys that differ.

One-time import from 1Password, run on qbert: `just import-secrets-to-gopass` (`extras/helpers/import-op-to-gopass.sh`). It authenticates with the service-account token file if present, else the desktop session (`--desktop` forces it). It pipes each value from `op read` into `gopass insert`, never prints one, skips entries that are present and non-empty, and refuses to store an empty read. Rerun it after a failure.

`--mirror` also copies every other credential field of every item in the `automation` and `nixerator` vaults to `<vault>/<item>/<field>` (slugged: lowercase, `-` for other characters), so new 1Password items need no map edit. It skips what must not be shared by the one GPG key: Documents and SSH keys (SSH identity keys, git-crypt keys, certificates stay in `MATERIALIZE`), service-account tokens, notes fields, and fields the map already covers. Two items with the same title get a short id suffix. `--dry-run` prints `would <entry>` lines and writes nothing. Only the `automation` and `nixerator` vaults are mirrored.

Cut-over order: import (`just import-secrets-to-gopass --mirror --dry-run`, then without `--dry-run`), `just check-secrets-gopass` until no key differs, then switch hosts from `render-secrets` to `render-secrets --from gopass`.

Cut-over state:

- srv renders after every pull: `apps.cli.secauto-pull.renderAfterPull = true` runs `render-secrets --from gopass` as `ExecStartPost`. The rendered file no longer carries `onepassword.serviceAccountToken`, so srv has no 1Password in its refresh path.
- fish no longer exports `OP_SERVICE_ACCOUNT_TOKEN` in any shell. `op` at the desk uses the desktop app. `op-toggle` opts one shell into the service account, using `~/.config/op/service-account-token` (install it with `just setup-op-token`). `render-secrets --from op` still reads that file by itself.
- qbert still renders with `render-secrets` (op mode) until you run `just render-secrets-gopass` there. `just check-secrets-gopass` should name only `onepassword.serviceAccountToken` as different.

## Accessing in modules

`secrets` still arrives via `specialArgs`, but for existence guards only, never
to read a value at eval. Reading a value at eval interpolates it into the build
output, and any `secrets.<x>` written into a derivation string lands in the
world-readable `/nix/store`, where a local agent can grep it (issue #265).

There are two consumption shapes, and one helper:

- Presence guards use `secrets` directly, and read no value (`secrets ? foo`,
  `secrets.foo.bar or null != null`).
- A runtime read (a value used live inside a service or shell script) is a
  one-line `jq` against the off-store file, as restic and the fish module do it:
  `set -gx TOKEN (jq -r '.foo.token' ~/.config/nixos-secrets/secrets.json)`. The
  value is read when the script runs, so it never enters the store.
- An activation write uses `secretsLib.installValue` (`lib/secrets.nix`). It
  writes one secret to a mode-restricted file, creates the parent dir, no-ops
  when the key is absent, and reads the value through `jq` so it never hits
  argv. This is the shape with real boilerplate, so it is the one worth sharing.

```nix
{ pkgs, lib, secretsLib, globals, secrets, ... }:
{
  config = {
    # Presence guard: reads nothing, only checks the key exists.
    someService.enable = secrets ? someService;

    # Activation write, to a 0600 file the consumer reads at runtime:
    system.activationScripts.fooToken = lib.stringAfter [ "etc" ] (
      secretsLib.installValue {
        jq = "${pkgs.jq}/bin/jq";
        secretsFile = secretsLib.file globals;
        path = ".foo.token";
        dest = "/run/nixos-secrets/foo-token";
      }
    );
  };
}
```

`flake.nix` still reads `secrets.json` at eval, but only to build the attrset
for those guards. No module interpolates a secret value into a build output, and
the acceptance grep in issue #265 enforces that.

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
6. Consume it at runtime: a one-line `jq` read for a shell/service, or
   `secretsLib.installValue` for an activation write. Guard on existence with
   `secrets`, but never interpolate the value at eval. See "Accessing in
   modules" above.
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
- **`(403) ... Service Account Deleted` on a bare `render-secrets` right after
  rotating the token** → `render-secrets` (through op-toggle) reads its token from
  the *rendered* `secrets.json`, which still holds the old, dead token until you
  re-render once with an explicit override. Run
  `OP_SERVICE_ACCOUNT_TOKEN="$(<~/.config/op/service-account-token)" render-secrets`
  (what `just rotate-op-token` step 3 does for you). A bare `render-secrets` works
  again afterward, since `secrets.json` now carries the fresh token.
- **A new `MATERIALIZE` key never appears** → check that the row reached the
  deployed binary: the commit has to be merged to `main` and the host rebuilt
  (see "Materialized host files" above). Verify by grepping the source or the
  wrapped payload, not `bin/render-secrets`.
- **`"Personal" isn't a vault in this account`** under SA mode → you're on a
  stale branch where `secrets.json.tpl` still references `op://Personal/…`;
  rebase onto main.
- **Drift between 1Password and the rendered file** → `just check-secrets`
  to see the diff, then `just render-secrets` to update.
