# Secrets Management

## Model: 1Password is the source, gopass is the snapshot

- 1Password is the only place a secret is edited. Add, change and rotate values
  there, in the `nixerator` or `automation` vault.
- gopass (the `secauto` store) is the automation snapshot. `just
  import-secrets-to-gopass`, run by hand on qbert, copies values from 1Password
  into it. Automations, services and headless hosts read gopass, not 1Password.
  A value that exists only in gopass is not covered by the next import.
- The `secauto` git repo moves the snapshot between hosts. qbert pushes, srv and
  the Mac pull every 15 minutes.
- 1Password also delivers the keys. SSH identity keys and git-crypt keys come
  from 1Password Documents through `render-secrets` (op mode) on workstations.
  The recovery copy of the GPG key that decrypts gopass is the 1Password
  Document `secauto-gpg-key` (Personal vault). Day to day, `just push-gpg-key
  <host>` streams it from qbert.
- Keys stay in 1Password. The identity-class files (SSH keys, git-crypt keys,
  `incus-ui.pfx`, `okular-*`) are never copied into gopass, because the one
  shared GPG key would expose them on every host. They are needed only on a new
  workstation install, so `render-secrets` op mode is a bootstrap path, not
  part of routine refreshes. Routine refreshes use `--from gopass`.
- **Automation never depends on 1Password (hard rule).** Anything that runs
  unattended reads gopass only: systemd units and timers, server modules,
  `secauto-pull`, and the `render-secrets` runs that follow a rebuild or a pull.
  Three things enforce it. `apps.cli.render-secrets.opSupport` is off by default,
  so `op` is not on `render-secrets`' PATH (only qbert turns it on). srv does not
  install the 1Password CLI. `modules/apps/cli/render-secrets/tests/no-op-in-automation.bats`
  fails when server modules, `secauto-pull` or `hosts/srv/modules.nix` call `op`,
  install it, or read the service-account token.
- The 1Password service-account tooling is retired: no token file, no
  `setup-op-token`, `rotate-op-token` or `op-toggle`, no `onepassword` key in the
  template, and the old bootstrap scripts are gone. 1Password itself stays, used
  through the desktop app only.

The sections below cover the 1Password flow first, then the gopass snapshot
(see "Automation secrets").

All sensitive content lives in the **`nixerator` 1Password vault** (automation
items in the `automation` vault). There are two flavours of consumer:

| Consumer | Source | Cached on disk |
|----------|--------|----------------|
| Nix flake eval (modules, hosts) | Items in the `nixerator` vault, snapshotted into gopass and rendered via `secrets.json.tpl` + `render-secrets` (`--from op` uses `op inject` instead) | `~/.config/nixos-secrets/secrets.json` (0600) |
| Okular signature stamping | Document items `okular-signature` + `okular-initials` in the `nixerator` vault | `~/.kde/share/icons/{signature,initials}.png` (0644) |
| gmailctl OAuth client | Login item `gmailctl` (`Client ID` + `Client Secret` fields) in the `nixerator` vault, mirrored to gopass (`nixerator/gmailctl/client-id`, `client-secret`) and written by `just fetch-gmailctl-creds` | `~/.gmailctl/credentials.json` (0600) |
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

**Who edits a secret.** A human types every secret edit in 1Password, and every
`gopass insert` or import run is a human action. The only exception is the
`opencode` CLI with a local model, and only when a human approves that run.
That `opencode` session may use the 1Password CLI (`op`), because a local model
sends nothing off the machine. The `Bash(op read*)` and `op item get --reveal`
deny rules in Claude's `settings.json` stay in force for Claude itself. A
secret value never goes back to Claude: not as command output, not as a diff,
not as a file Claude reads. Claude may write the scripts, templates and docs
around the flow, and may run a command only when its output carries no value
(exit status, entry names, present/absent).

The global rule in `~/.claude/CLAUDE.md` states this prohibition inline and
points here for the mechanics above.

## One-time per-host setup

A host needs the secauto GPG key and a clone of the store first (see "Automation
secrets"). A brand-new machine gets both from `bootstrap-install-gopass.sh`
(see `bootstrap.txt`).

1. **Render the Nix-eval secrets file** (from the gopass snapshot):
   ```bash
   just render-secrets      # writes ~/.config/nixos-secrets/secrets.json
   ```
   On a new workstation, also restore the identity-class keys from 1Password:
   ```bash
   just render-secrets-op   # render-secrets --from op: SSH keys, git-crypt keys, incus-ui.pfx
   ```

2. **Fetch the Okular signature PNGs** (only on hosts where you use Okular;
   needs the 1Password desktop app):
   ```bash
   just fetch-signatures    # writes ~/.kde/share/icons/{signature,initials}.png
   ```

All steps are idempotent — safe to re-run any time.

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
| `~/.local/share/filebot/data/.license` | 0600 | srv has no desktop 1Password session; the license only reaches it via `--push` from a workstation that materialized it locally |

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
# 1. Update the value in 1Password (you, by hand), in the matching
#    nixerator/<item>. See the item table below for which item holds which secret.

# 2. Refresh the gopass snapshot on qbert and push the store (you, by hand):
just import-secrets-to-gopass   # skips present entries: gopass rm the old one first
#    other hosts pick it up on their next secauto pull

# 3. Re-render locally from gopass:
just render-secrets          # alias: rs

# 4. Push the new file to any peer that needs it:
just push-secrets srv        # one host           (alias: ps)
just push-secrets srv qbert  # several hosts

# 5. Rebuild as usual:
just qr                      # local
just remote-rebuild srv      # remote
```

Rendering reads gopass, so it needs no 1Password session and no biometric prompt.

## Drift check

```bash
just check-secrets           # alias: cs
```

Renders from the gopass snapshot to a tempfile (inside `~/.config/nixos-secrets/`,
never `/tmp`) and diffs against the live cached file. Exits non-zero on drift.
Read-only. `just check-secrets-gopass` (`csg`) is the same check spelled out.
Drift between 1Password and the gopass snapshot is not detected here: re-run
`just import-secrets-to-gopass` after a 1Password change.

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

Names are pinned — they must match `secrets.json.tpl` exactly. Each item is
snapshotted into gopass under the entry named in
`modules/apps/cli/render-secrets/gopass-map.tsv` (for example `aha/credential`
for `op://nixerator/aha/credential`); `--mirror` adds the rest as
`<vault>/<item>/<field>`.

| Item | Type | Fields | Consumed as |
|------|------|--------|-------------|
| `kong-konnect-pat` (now in the `automation` vault) | API Credential | `lab-pat-2026-06` | `secrets.kong.kongKonnectPAT` |
| `Tableau-PAT` (now in the `automation` vault) | API Credential | `hostname` (full `https://` origin, not a bare host), `Site-Name`, `username`, `credential` | `secrets.tableau.{server,siteName,patName,patValue}` (self-hosted/local Tableau MCP against Kong's Tableau Cloud site; injected as `SERVER`/`SITE_NAME`/`PAT_NAME`/`PAT_VALUE` by the claude-code module; workstation-only, see `serverProfile` gate in `mcp-servers.nix`) |
| `aha` | API Credential | `credential` | `.aha.apiToken` in the rendered blob (read by `aha-fr-report`) and the gopass entry `aha/credential` (the `aha` skill reads it at run time) |
| `wave` | API Credential | `credential` | gopass entry `wave/credential`, read at run time by the `wave-invoicing` skill (not in the rendered blob; Wave Full Access Token — personal-use bearer, no OAuth) |
| `forgejo-api` | API Credential | `token` | `.forgejo.apiToken` in the rendered blob, read at **runtime** (never through the Nix store): skills and `forge` read it at run time from the gopass entry `forgejo-api/token` for the Forgejo (`git.srvrs.co`) REST API (no shell exports `FORGEJO_TOKEN` any more), and the git module renders `~/.config/tea/config.yml` for the `tea` CLI. High-privilege token — skills using it default read-only and gate writes. |
| `zai` | API Credential | `credential` | gopass entry `zai/credential` only (not in the rendered blob, no Nix reader) |
| `gemini` | API Credential | `credential` | gopass entry `gemini/credential`, read at run time by the `agy` wrapper (not in the rendered blob) |
| `snyk` | API Credential | `credential` | gopass entry `snyk/credential`, read at run time by the `snyk-agent-scan` wrapper (not in the rendered blob) |
| `tailscale-caddy-authkey` | API Credential | `credential` | `secrets.tailscale.caddyAuthKey` |
| `github-pat` | API Credential | `credential` | `secrets.github.accessToken` |
| `todoist` | API Credential | `credential` | `secrets.todoist_token` |
| `syncthing-gui` | Login | `username` + `password` | `secrets.syncthing.gui.*` |
| `b2-credentials` | Secure Note | `keyID` + `applicationKey` | `secrets.restic.*.b2_account_*` (shared) |
| `restic-password` | Password | `password` | `secrets.restic.{srv,workstation}.restic_password` (shared) |
| `restic-srv` | Secure Note | `repository` + `region` | `secrets.restic.srv.{restic_repository,region}` |
| `restic-workstation` | Secure Note | `repository` + `region` | `secrets.restic.workstation.{restic_repository,region}` |
| `okular-signature` | Document | `file` | `~/.kde/share/icons/signature.png` (via `just fetch-signatures`) |
| `okular-initials` | Document | `file` | `~/.kde/share/icons/initials.png` (via `just fetch-signatures`) |
| `homelab git-crypt key` | Document | `file` | `~/.config/git-crypt/homelab.key` (via `render-secrets`) |
| `id_ed25519{,_np,.pub}`, `id_rsa{,.pub}`, `id_rsa_np.pub` | Document | `file` | `~/.ssh/<name>` on workstation hosts (via `render-secrets`) |
| `mixerator-`, `nixcfg-`, `nixerator-`, `talos-vms-git-crypt-key` | Document | `file` | `~/.ssh/<name>` on workstation hosts (via `render-secrets`) |
| `feral-arr`, `feral-arr.pub` | Document | `file` | `~/.ssh/feral-arr{,.pub}` on srv + workstation hosts (via `render-secrets`). Single-purpose key for darkstar's arr download-sync CronJob rsync from the feralhosting seedbox; also consumed in-cluster by homelab's `just workloads::create-arr-ssh-secret`, which reads the same 1Password document. |
| `gmailctl` | Login | `Client ID` + `Client Secret` | `~/.gmailctl/credentials.json` (via `just fetch-gmailctl-creds`, which reads the two gopass entries `nixerator/gmailctl/client-id` and `client-secret` (from `import-secrets-to-gopass --mirror`) into a Desktop-app credentials.json template). Rendered straight to disk, **not** in `secrets.json` — keeps the client secret out of the Nix store. `gmailctl init` then writes `~/.gmailctl/token.json` locally. |
| `incus-ui.crt` | Document | `file` | `~/.config/incus/client.crt` on all hosts (via `render-secrets` MATERIALIZE, 0644). Public certificate read by the Incus module via `builtins.readFile` at Nix eval time and injected into the preseed trust store. All Incus hosts; safe to be world-readable. |
| `incus-ui.pfx` | Document | `file` | `~/.config/incus/client.pfx` on workstations (via `render-secrets` MATERIALIZE, 0600). PKCS12 bundle with private key; import into a browser to authenticate against any Incus web UI. Workstations only — srv is headless. |
| `filebot-license` | Document | `file` | `~/.local/share/filebot/data/.license` on srv (via `render-secrets` MATERIALIZE + PUSH_ALONGSIDE, 0600). FileBot lifetime license (`.psm`) used by `dlm`/`dltv` (`modules/apps/cli/media-rename`) to rename/organize media. Materializes on any host running `render-secrets` but is only meaningful on srv, which gets it via `just push-secrets srv`. |
| `snowflake-connections-toml` | Document | `file` | `~/.snowflake/connections.toml` on workstation hosts (via `render-secrets` MATERIALIZE, 0600). No secret value inside -- auth is externalbrowser (interactive SSO, no password/token) -- just kept out of git because it names the internal Snowflake account locator/role/warehouse/database/schema. Consumed by `apps.cli.snowstorm` (the `snowstorm` Snowflake data-access CLI). |

Per-host network identity (Tailscale IPs, syncthing peer IDs) is NOT in 1P;
those values live in `settings/globals.nix` under
`hosts.{qbert,srv}` because they're already published in
plaintext docs in this repo and don't grant access on their own.

### Authentication

Plain `render-secrets` reads gopass and uses no 1Password auth. The commands that
do call `op` (`render-secrets --from op`, `import-secrets-to-gopass`,
`fetch-signatures`) use the 1Password desktop app: the CLI integration prompts for
approval per the app's settings. There is no service-account token anywhere in this
repo.

## Automation secrets (secauto)

Unattended jobs read their secrets from gopass, not from 1Password. Service-account tokens expire, and `op` falls back to the desktop prompt in any process that lacks the token, so a headless job cannot rely on it. A gopass read needs only the local GPG key: no expiry, no network login.

How it fits together:

- The store is the private repo `bashfulrobot/secauto`. It holds one GPG-encrypted file per secret, plus `.gpg-id`. The decrypting key is never in the repo.
- qbert is the only writer. It commits and pushes from its clone at `~/git/secauto`.
- Reader hosts (srv, the Mac) keep a clone at `~/.local/share/gopass/stores/root`. On NixOS, `apps.cli.secauto-pull` runs `git pull --ff-only` every 15 minutes over a read-only deploy key. It checks the server against GitHub's published host keys pinned in the module (`github-known-hosts`, never trust-on-first-use) and ignores the user's ssh config, so a ControlMaster or ProxyCommand there cannot bypass the check.
- One passphrase-less GPG key (uid `secauto automation`) decrypts the store on every host. This is a deliberate single-key design, not an oversight: it keeps the model simple, and it is why SSH keys, git-crypt keys and `okular-*` stay in 1Password only. The recovery copy is the 1Password Document `secauto-gpg-key` in the Personal vault, which service accounts cannot read. Open it only to rebuild a host or after losing every other copy.

Setting up a reader host (once):

1. Install `gopass` and `gnupg` (the dev suite on NixOS, `Brewfile.core` on the Mac).
2. Import the key. On qbert, `just push-gpg-key <host>` (alias `pgk`) does this for NixOS peers: it streams the key over SSH, sets trust, and skips a host that already has it (allow-list qbert, srv, clanker). For the Mac, run the commands below. Without the loopback flags, gpg can open a pinentry to set a passphrase, which would bring the prompt back:
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

Add or rotate a secret in 1Password first, then refresh the snapshot on qbert. A new value: `just import-secrets-to-gopass` (it skips entries that are already present and non-empty). A changed value: `just import-secrets-to-gopass --update`, which compares each mapped entry with 1Password by sha256 and overwrites only the ones that differ (add `--dry-run` to preview). Then push the store.

Check that the snapshot still matches 1Password with `just check-snapshot` (`import-secrets-to-gopass --check`): it prints entry names only, exits non-zero on drift or a missing entry, and on a clean pass writes a stamp (`~/.local/state/nixerator/snapshot-verified`). On qbert the rebuild recipes warn when that stamp is missing or older than 7 days. `--update` and `--check` cover the template map only, not `--mirror` or `--documents`.

A row in `gopass-map.tsv` can carry a third column, `required`. If a required entry is missing or empty, `render-secrets --from gopass` fails and leaves the live file unchanged, because what it guards fails open without it (today: the Syncthing GUI login). Every other missing key is still just left out. `RENDER_SECRETS_ALLOW_MISSING=1` overrides this for a bootstrap render. Never paste a value into an AI transcript. Readers pick it up on their next pull. A job that reads at run time (`gopass show -o <name>`) gets the new value on its next run. A service that read the value at startup, or a file an activation script wrote once, keeps the old value until it restarts or the host rebuilds.

Rules for AI assistants: never run `gopass show`, `gopass cat` or `pass show`, and never print the GPG private key. `gopass ls` (names only) is fine.

### What the pull trusts

`secauto-pull` ignores the user's gitconfig and ssh config, pins GitHub's host keys, and refuses to pull when the clone's `origin` differs from `apps.cli.secauto-pull.repo`. By default it does not verify commit signatures, because the gopass commits on qbert are unsigned. `apps.cli.secauto-pull.allowedSignersFile` turns verification on (`git pull --verify-signatures` against an SSH allowed-signers file). Turn it on in this order: configure qbert to sign its store commits with an SSH key (`gpg.format=ssh`, `commit.gpgsign=true` in the clone), put that key's public half in the allowed-signers file on each reader, then set the option and rebuild. Setting the option before qbert signs makes every pull fail. Anyone with push access to `bashfulrobot/secauto` can add entries encrypted to this host's key, and those values become env vars and files on srv. Write access is the same GitHub account that holds the deploy keys. Keep the repo private, keep 2FA on that account, and review `git log` on the store after a surprise change. The single-key decision and the bootstrap redesign are in `secrets-roadmap.md`.

`gcommit` (`agy`) runs in plan mode without `--dangerously-skip-permissions`, because the diff it reads is untrusted text.

### No exported API tokens

No shell exports an API token. A shell export reaches every child process, including a Claude Bash tool, while a value read at run time lives only in the process that needs it. Each consumer gets its value from the store:

- Scripts read the gopass entry when the variable is unset (an exported value still wins; `GOPASS_FALLBACK=off` disables the lookup): `aha.sh` (`aha/credential`), `grafana.sh` and `grafana-query.sh` (`grafana-cloud-dashboards/token`), the wave-invoicing `lib.sh` (`wave/credential`), `forge.sh` and `release-create.sh` (`forgejo-api/token`) in claude-skills, and nixerator's `forge` and `todoist-report`.
- CLIs that read the variable themselves are wrapped by `secretsLib.withGopassEnv` (`lib/secrets.nix`), which exports it for the wrapped command and the children it starts (a tool that spawns sub-agents passes it on; it calls the store-pinned `gopass`, not one from `PATH`): `td` (`TODOIST_API_TOKEN` from `todoist/credential`), `snyk-agent-scan` (`SNYK_TOKEN` from `snyk/credential`) and `agy` (`GEMINI_API_KEY` from `gemini/credential`).
- To wrap another CLI, call `withGopassEnv { inherit pkgs; pkg = ...; bin = "..."; envVar = "..."; entry = "..."; }` in its module.

Check that nothing exports one (fish, any host): `for v in AHA_API_TOKEN WAVE_FULL_ACCESS_TOKEN FORGEJO_TOKEN TODOIST_API_TOKEN GEMINI_API_KEY SNYK_TOKEN GRAFANA_TOKEN; set -q $v; and echo "$v: set"; or echo "$v: unset"; end`.

### Rendering `secrets.json` from gopass

`render-secrets --from gopass` (`just render-secrets-gopass`, alias `rsg`) fills the same `secrets.json.tpl` from the store, so the Nix modules, fish exports and flake guards keep reading the file they already read. No `op`, no service-account token, no desktop prompt, so it runs on srv, in a timer or over SSH.

- `modules/apps/cli/render-secrets/gopass-map.tsv` maps each gopass entry to the `op://` reference the template uses (`aha/credential` ↔ `op://nixerator/aha/credential`). Names and references only. Add a row there when you add a template key.
- A key is left out of the file, never written empty, when its reference is not in the map or its entry is missing or empty. Modules already guard on presence. The stderr list names entries, not values.
- Automation Documents (listed in `gopass-documents.psv`) restore from gopass. SSH identity keys and git-crypt keys still restore through `render-secrets` in `op` mode, and `--from gopass` skips them.
- The map and the Documents table are baked into the script. `GOPASS_MAP`, `GOPASS_DOCS` and `RENDER_SECRETS_HOSTNAME` are honoured only under test (`RENDER_SECRETS_SOURCE_ONLY` or `RENDER_SECRETS_TEST`), because the table decides which paths get written and chmod'ed. A symlink at a destination is refused.
- `just check-secrets-gopass` (`csg`) compares the live file with a gopass render and names the keys that differ.

One-time import from 1Password, run on qbert: `just import-secrets-to-gopass` (`extras/helpers/import-op-to-gopass.sh`). It uses the 1Password desktop app. It pipes each value from `op read` into `gopass insert`, never prints one, skips entries that are present and non-empty, and refuses to store an empty read. Rerun it after a failure.

`--mirror` also copies every other credential field of every item in the `automation` and `nixerator` vaults to `<vault>/<item>/<field>` (slugged: lowercase, `-` for other characters), so new 1Password items need no map edit. It skips what must not be shared by the one GPG key: Documents and SSH keys (SSH identity keys, git-crypt keys, certificates stay in `MATERIALIZE`), service-account tokens, notes fields, and fields the map already covers. Two items with the same title get a short id suffix. `--dry-run` prints `would <entry>` lines and writes nothing. Only the `automation` and `nixerator` vaults are mirrored.

`--documents` copies the automation-class Documents listed in `modules/apps/cli/render-secrets/gopass-documents.psv` from the `nixerator` vault into gopass as `documents/<title>`: the feral-arr SSH key and its `.pub`, `incus-ui.crt`, the flux deploy key and its `.pub`, `filebot-license`, and `snowflake-connections-toml`. Keys and the license are stored as base64 of the exact bytes (a private key needs its trailing newline), the rest as text. On its own `--documents` imports only these (the template map is skipped); add `--mirror` to run both. Each read is captured first and an empty read is never stored. `render-secrets --from gopass` then restores them to their destinations (same modes, guards and no-clobber rule as `MATERIALIZE`), so srv and a workstation need no `op` for them. An entry that is not imported yet only warns, so a render does not fail before the import. The SSH identity keys, git-crypt keys, `incus-ui.pfx` and `okular-*` are deliberately not in the table: the one shared GPG key would expose them on every host, so they stay in `MATERIALIZE` (`--from op`, workstations only). The Mac's chezmoi template reads `documents/snowflake-connections-toml` directly.

Cut-over order: import (`just import-secrets-to-gopass --mirror --dry-run`, then without `--dry-run`), `just check-secrets-gopass` until no key differs, then switch hosts from `render-secrets` to `render-secrets --from gopass`.

Cut-over state:

- srv renders after every pull: `apps.cli.secauto-pull.renderAfterPull = true` runs `render-secrets --from gopass` as `ExecStartPost`. srv has no 1Password in its refresh path.
- fish exports no 1Password token. `op` at the desk uses the desktop app.
- `claudoist` and `incident-investigator` (and their cloudflared tunnels) on srv no longer use `op run` or the service-account token. `secretsLib.gopassRun` (`lib/secrets.nix`) replaces every `op://vault/item/field` value in the service environment with the first line of the gopass entry `vault/item/field` (slugged like `--mirror`), then execs the command. A missing or empty entry stops the service and names the variable and entry, never a value. Restarting them needs only the local GPG key.
- The `claudoist-helper` user unit on qbert holds the key only in its own environment (resolved by `secretsLib.gopassRun` at start). The DankBar claudoist widget reads the helper over an owner-only unix socket in `$XDG_RUNTIME_DIR` and never needs the key, so no key file is written. The Mac's SwiftBar plugin still reads its own token file.
- Nothing uses the service account any more. The tooling was removed after the gopass cut-over (see `secrets-roadmap.md`).
- `render-secrets` defaults to `--from gopass` on every host (`RENDER_SECRETS_FROM` overrides it). `--from op` (`just render-secrets-op`) remains for restoring the identity-class keys on a new workstation.

### Cluster sync (homelab)

qbert copies the secauto entries into the darkstar cluster once a day, so a secret changed here reaches External Secrets Operator without a manual step. The module is `apps.cli.homelab-secret-sync` (`modules/apps/cli/homelab-secret-sync/`), enabled in `hosts/qbert/modules.nix`. Only qbert enables it, because only qbert edits secrets.

A user timer fires at 06:30 (persistent, with up to 10 minutes of random delay) and runs `homelab-secret-sync`. That wrapper runs the homelab repo's `scripts/sync-secauto.sh`, which reads the entries listed in `manifests/base/external-secrets/gopass-map.tsv` and applies them as the Secrets `secauto-automation` and `secauto-nixerator` in the `eso-source` namespace. Values pass through pipes, and the script checks that every entry exists before it writes anything.

The unit refuses to run, and fails, unless `~/git/homelab` is on `main` with no local edits to the script or the map. If the GPG key needs a passphrase that gpg-agent no longer has cached, the run fails until the key is unlocked once. A failed run leaves the cluster's previous Secrets in place.

Run it by hand with `systemctl --user start homelab-secret-sync`, and read the result with `journalctl --user -u homelab-secret-sync`.

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

- **Pre-install** (on the live USB, after `git clone`, as root):
  ```bash
  SOURCE_SSH=user@host INSTALL_USER=dustin ./extras/helpers/bootstrap-install-gopass.sh stage
  ```
  Streams the secauto GPG key and the encrypted store from an existing host over
  SSH and renders secrets into `/home/dustin/.config/...` so `nixos-install` can
  read them.

- **Post-install, before reboot**:
  ```bash
  INSTALL_USER=dustin ./extras/helpers/bootstrap-install-gopass.sh promote
  ```
  Copies the staged files into `/mnt/home/dustin/...` and chowns them to the
  install user via `nixos-enter`.

- **After first boot** (needs the 1Password desktop app):
  ```bash
  just render-secrets-op       # SSH keys, git-crypt keys, incus-ui.pfx
  just fetch-signatures        # only if you use Okular on this host
  ```

`bootstrap-install-gopass.sh` has not run on a real install yet; try it in a VM
first.

## Troubleshooting

- **`builtins.readFile: No such file or directory`** during rebuild → the
  rendered file is missing. Run `just render-secrets` (or
  `just push-secrets <thishost>` from a peer).
- **`render-secrets: left out N key(s) not available from gopass`** → the
  snapshot lacks those entries. Add them in 1Password, run
  `just import-secrets-to-gopass` on qbert, wait for the secauto pull, then
  re-render.
- **`render-secrets: 'gopass' not in PATH`** or a GPG decrypt failure → the host
  lacks `gopass`/`gnupg` or the secauto key. See "Setting up a reader host".
- **`render-secrets: 'op' (1Password CLI) not in PATH`** (only with `--from op`)
  → host doesn't have 1Password installed. Enable `apps.gui.one-password` +
  `apps.cli.render-secrets` on this host.
- **`op` asks to sign in, or `account is not signed in`** (only with `--from op`
  and the other `op` commands) → unlock the 1Password desktop app and make sure
  its CLI integration is on.
- **A new `MATERIALIZE` key never appears** → check that the row reached the
  deployed binary: the commit has to be merged to `main` and the host rebuilt
  (see "Materialized host files" above). Verify by grepping the source or the
  wrapped payload, not `bin/render-secrets`.
- **`"Personal" isn't a vault in this account`** under SA mode → you're on a
  stale branch where `secrets.json.tpl` still references `op://Personal/…`;
  rebase onto main.
- **Drift between 1Password and the rendered file** → `just check-secrets`
  to see the diff, then `just render-secrets` to update.
