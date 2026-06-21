# Porting secrets to agenix / sops-nix — an evaluation

> Prompted by Isabel Roses' write-up: <https://isabelroses.com/blog/nixos-and-secrets/>.
> This is a decision document, not a migration plan. It inventories where
> nixerator actually needs secrets today, then asks whether agenix or sops-nix
> would cover those cases — and whether the move is worth it.

## TL;DR

- **The one thing a move buys you:** plaintext secrets out of `/nix/store`.
  Today every secret value is string-interpolated into the store at eval time
  (it is world-readable to any local process). Your current system keeps
  secrets out of **git**, but not out of the **store**. That gap is exactly
  what agenix/sops-nix close, and it is the *only* security property they add
  over what you have.
- **Would agenix cover all your use cases? No.** Neither tool does, natively.
  Both are fundamentally "decrypt to a file path, hand the path to a service."
  Roughly half of nixerator's secrets are consumed as **env vars** or
  **values templated into a config file** for user-facing CLI tools — the
  category where path-based secret managers are weakest.
- **Between the two, sops-nix fits this repo better than agenix** — because it
  keeps your single-blob model, its *templates* handle the "secret embedded in
  a JSON/conf file" cases, and its home-manager module covers the user-level
  secrets. agenix is conceptually cleaner (one secret = one file) but its
  no-templating, one-file-per-secret model fights most of your consumers.
- **The real decision isn't agenix-vs-sops. It's whether you give up 1Password
  as the source of truth**, or run two systems. See "The 1Password tension".

## What the blog post actually argues

Roses' position, condensed:

- Never put plaintext secrets in the config, a private repo, or git-crypt —
  they end up world-readable in `/nix/store`.
- Hand services a **path** (`/run/secrets/<name>`) that is decrypted at
  **runtime** onto tmpfs, never the value itself at eval time.
- **agenix for simpler setups** ("one secret, one file, one list of
  recipients", no schema), **sops-nix for complex deployments** (bundles many
  related values, supports templates mixing plaintext + secrets).
- Both are host-key (SSH/age) based and work system-wide via their NixOS
  modules. The post glosses over user-vs-system and home-manager nuances —
  which, as it happens, is precisely where nixerator's hard cases live.

## How nixerator does secrets today (the relevant mechanics)

`flake.nix:133`:

```nix
secrets = builtins.fromJSON (builtins.readFile secretsFile);
```

A single `~/.config/nixos-secrets/secrets.json` (rendered from 1Password via
`op inject`) is read at eval time into a `secrets` attrset, passed to every
module through `specialArgs`. Modules then **interpolate the value**:

```nix
nix.settings.access-tokens = "github.com=${secrets.github.accessToken}";   # → /etc/nix/nix.conf
"TS_AUTHKEY=${secrets.tailscale.caddyAuthKey}"                             # → systemd unit Environment=
environment.etc."cloudflare-ddns/token".text = secrets.cloudflareDdns...   # → /nix/store, /etc (0400)
RESTIC_PASSWORD "${bcfg.password}"                                          # → writeScriptBin in /nix/store
TODOIST_API_TOKEN = secrets.todoist_token;                                  # → env var, system + user
Authorization = "Bearer ${secrets.kong.kongKonnectPAT}";                   # → MCP servers JSON config
```

**Every one of those interpolations lands the plaintext in `/nix/store`,**
which is `0755`/world-readable. The repo even documents this as an accepted
trade-off (`modules/server/cloudflare-ddns/default.nix:265`: *"the plaintext
copy in /nix/store is the documented trade-off for inline secrets"*).

So the current model's security posture is:

| Property | Status today |
|---|---|
| Secrets out of git history | ✅ Yes (rendered file is off-tree, off-store-as-input) |
| Secrets out of the AI agent's reach | ✅ Yes (deny-listed paths, hard rule) |
| Single source of truth + nice rotation UX | ✅ Yes (1Password + `render-secrets`) |
| Secrets out of `/nix/store` (not world-readable locally) | ❌ **No** |
| Secrets decrypted at runtime onto tmpfs | ❌ No |

A migration to agenix/sops only moves the bottom two rows. **If a local
unprivileged reader of `/nix/store` is not in your threat model, the migration
buys you very little.** On single-user workstations (`donkeykong`, `qbert`)
you're effectively the only principal anyway. On `srv` — a server with more
surface and potentially more service accounts — the property is worth more.

## Inventory: every consumer, and how cleanly it ports

Bucketed by how the secret is consumed, because that — not the secret itself —
determines fit.

### Bucket A — service credential *files*. Clean fit for either tool.

These map directly onto `age.secrets.<x>.path` / `sops.secrets.<x>.path`:

| Consumer | Today | Ported |
|---|---|---|
| `harmonia` signing key | `environment.etc` text, `0400` | harmonia's `settings.signKeyPaths` already wants a **path** → point it at the decrypted path. Textbook fit. |
| `cloudflare-ddns` token | `environment.etc."cloudflare-ddns/token"` | mount the decrypted file at that path instead. |
| `caddy` `TS_AUTHKEY` | systemd `Environment=` | `serviceConfig.EnvironmentFile = <decrypted path>`. Clean. |

### Bucket B — restic / plakar. Should be clean, but needs a rewrite.

`restic` is the textbook agenix use case (`passwordFile`, `environmentFile`,
`repositoryFile` all take paths). But you're **not** using
`services.restic.backups`; you hand-rolled a `writeScriptBin "backup-mgr"`
fish script with the password, repo, and B2 keys **interpolated straight into
the store path** (`modules/apps/cli/restic/default.nix:17-21`). This is the
single worst exposure in the repo.

Porting means rewriting `backup-mgr` to read `RESTIC_PASSWORD` / `AWS_*` from
an `EnvironmentFile` / decrypted paths at runtime (or adopting the upstream
`services.restic` module, which already does this). Worth doing regardless of
which secrets tool you pick — even reading from the existing `secrets.json` at
runtime instead of baking values in would be an improvement.

Shared values (`b2-credentials`, `restic-password`) currently fan out to
srv/qbert/donkeykong via the JSON blob. agenix would push you to one `.age`
file per (host × value) or duplicate; sops keeps the single-doc fan-out.

### Bucket C — env vars for interactive shells. **Neither tool covers this natively.**

| Consumer | Today |
|---|---|
| `todoist-cli` | `environment.variables` + `home.sessionVariables.TODOIST_API_TOKEN` |
| `claude-code` | `GEMINI_API_KEY`, `AHA_API_TOKEN`, `WAVE_FULL_ACCESS_TOKEN` env |
| `gemini-cli`, `agent-scan` (snyk) | env / wrapper |

agenix and sops both produce **files**, not environment variables. For systemd
services you bridge with `EnvironmentFile=`. But there is **no clean
file→env-var path for an interactive login shell** (`home.sessionVariables`).
Porting these means a shell-init shim that `source`s a decrypted env file on
every shell start — which you'd have to write and maintain *yourself*,
identically, no matter which tool you choose. This bucket is the main reason
"agenix covers everything" is false for nixerator.

### Bucket D — secrets templated into config *files*. Needs sops templates (or activation rendering).

| Consumer | Today |
|---|---|
| `claude-code` MCP servers (`context7`, `kong`) | `Authorization: Bearer …` baked into an MCP JSON config |
| `nix.settings.access-tokens` (github) | `github.com=<token>` in `/etc/nix/nix.conf` |
| `syncthing` GUI user/password | `services.syncthing.settings.gui.{user,password}` |

These need a secret *interpolated into a larger file*. agenix has no
templating — you'd render these at home-manager **activation** time yourself.
sops-nix has **`sops.templates`** (system) and a home-manager equivalent that
does exactly this: render a file mixing plaintext + `placeholder."x"`,
decrypted to a runtime path. `nix.conf` specifically supports `!include
<path>` so the github token can live in an included, decrypted file.
syncthing has no `passwordFile`, so it stays awkward either way (its password
gets hashed into config regardless).

### Bucket E — already out-of-band. No change needed.

`okular-signature` / `okular-initials` PNGs and `gmailctl` credentials.json are
rendered **straight to disk** by `just` recipes, never through Nix. They never
touch the store today. Leave them alone; they're already doing the right thing
and are a decent template for the env-var cases (render to a runtime path,
don't go through eval).

### Scorecard

| Bucket | # of secrets (approx) | agenix | sops-nix |
|---|---|---|---|
| A: service files | 3 | ✅ clean | ✅ clean |
| B: restic/plakar | 4 | ✅ after rewrite | ✅ after rewrite |
| C: shell env vars | 5–6 | ⚠️ DIY shim | ⚠️ DIY shim |
| D: templated configs | 3 | ❌ DIY activation | ✅ native templates |
| E: out-of-band | 2 | n/a | n/a |

## agenix vs sops-nix, for *this* repo specifically

**agenix**
- *Pros:* tiny, no schema, one secret = one file; easy to reason about; great
  if you were mostly Bucket A.
- *Cons here:* no templating (Bucket D becomes hand-rolled activation scripts);
  one-file-per-secret multiplies ~20 secrets × hosts into a lot of `.age`
  files and a `secrets.nix` recipients map; shared values (b2, restic password)
  duplicate; home-manager support is community/less-trodden.

**sops-nix**
- *Pros here:* keeps your **single-blob** mental model (one encrypted
  YAML/JSON ≈ your current `secrets.json`); **templates** solve Bucket D
  natively; mature **home-manager module** for the user-level secrets;
  per-key access. Closest structural match to what you already have.
- *Cons:* a schema/format to maintain; more concepts (key groups, creation
  rules, templates) than agenix; YAML.

**For nixerator, sops-nix is the better technical fit** — driven entirely by
Buckets C and D, which dominate your consumer list. agenix would leave you
writing the same templating/activation glue by hand.

## The 1Password tension (the actual decision)

This is the part the blog post doesn't touch and it matters more than the
tool choice. agenix/sops want the **source of truth** to be encrypted files
**in your repo**, encrypted to **host SSH/age keys**. Today your source of
truth is **1Password**, with biometric/SA-token UX and one-place rotation.

Three ways to reconcile:

1. **Replace 1Password with sops/agenix.** Source of truth becomes the
   encrypted files; you manage age keys and recipients. You *lose* the
   1Password UX (biometrics, rotation in one place, the item table, mobile
   access) for these secrets. Cleanest tooling, biggest workflow change.
2. **Keep 1Password, add sops/agenix as the deploy path.** A script pulls from
   1Password and re-encrypts into the repo (`op read … | sops --encrypt`).
   You keep the nice human UX *and* get store-free runtime — but you now run
   **two systems** and a sync step. More moving parts than today.
3. **Don't migrate; close the gap in place.** Keep 1Password + `render-secrets`,
   but stop interpolating values into the store: render the relevant secrets to
   **runtime paths** (you already do exactly this for okular/gmailctl) and feed
   services `EnvironmentFile=`/`passwordFile=` pointing at them. This gets you
   ~80% of the security benefit (plaintext out of the store) with **zero new
   dependencies** and no change to your source of truth. It does *not* give you
   age-encrypted-at-rest-in-repo or runtime decryption from ciphertext — but
   you don't have ciphertext in the repo today anyway, so that's not a
   regression.

## Recommendation

1. **First, fix the worst offender regardless of any tool decision:** rewrite
   `backup-mgr` so restic creds aren't interpolated into a store-path script.
   That's the highest-value, lowest-risk change and it's independent of
   agenix/sops.
2. **Decide on the 1Password question before the tool question.** If you're not
   willing to give up the 1Password UX, **option 3 (close the gap in place)**
   is the pragmatic win and keeps your whole existing flow. If you *want*
   encrypted-in-repo + runtime decryption as a first-class property (most
   defensible on `srv`), go **sops-nix**, not agenix, because of Buckets C/D.
3. **Don't expect any tool to cover the shell-env-var secrets (Bucket C)
   cleanly.** Plan a small `source`-an-env-file shim for those whichever path
   you take, and model it on the okular/gmailctl out-of-band pattern you
   already trust.

In one line: *agenix would not cover all your cases; sops-nix covers more of
them; but the highest-leverage move is getting plaintext out of `/nix/store`,
which you can do without adopting either tool.*
