# NanoClaw on srv

NanoClaw ([nanocoai/nanoclaw](https://github.com/nanocoai/nanoclaw)) is a
personal AI assistant. It runs as one Node.js host process that starts one
Docker container per agent session. srv runs it declaratively through
`server.nanoclaw` (`modules/server/nanoclaw/`). It authenticates with the
Claude **subscription** via a `claude setup-token` OAuth token, never an API
key. The credential lives in the **OneCLI Agent Vault**, and agent containers
only ever see `CLAUDE_CODE_OAUTH_TOKEN=placeholder`.

## Read first: caveats and deviations

- **Secrets use the repo's one pattern.** The four values live in the
  `nixerator` 1Password vault, render to `secrets.json` with
  `just render-secrets`, and land at `/run/nanoclaw-secrets/<name>` (root,
  0400) through `secretsLib.installValue` at activation. See
  `extras/docs/secrets.md`. agenix was used in the first version of this
  module and removed: on single-user hosts keeping values out of `/nix/store`
  is already covered by `installValue`, and a second mechanism cost more than
  it bought.
- **The service stays off until the core keys exist in `secrets.json`.**
  Until then, srv builds normally and evaluation prints a warning.
- **This is not upstream's topology.** Upstream publishes OneCLI's admin API
  and proxy on docker0. Under egress lockdown it attaches the whole OneCLI
  container to the agents' network. On OneCLI 1.41.0 and 1.42.0 that API is
  unauthenticated in local mode. From inside an agent container we could list
  secrets and `PATCH` the `Anthropic` secret, including its `hostPattern`. A
  prompt-injected agent could therefore point the gateway at a host it
  controls, and the gateway would inject the real token there. This module
  closes that gap:
  - The API is published on `127.0.0.1` only.
  - Agents reach a socat relay (`onecli-gateway`, built from nixpkgs) that
    forwards the proxy port and nothing else.
  - Verified: from an agent, the admin API refuses the connection and
    proxied Anthropic traffic still reaches the gateway.
- **Any local process on srv can reach the vault API** (loopback, no auth in
  OneCLI's local mode). That's acceptable on a single-user box, but don't
  add untrusted local users or services to srv.
- **The `nanoclaw` user is in the `docker` group, which is root-equivalent.**
  Upstream needs this so the host can start agent containers. The security
  boundary that matters is the agent container, not the host user.
- **Building the agent image needs the network at runtime.**
  `nanoclaw-agent-image` runs upstream's own `container/Dockerfile` from the
  store copy. Inside the build it does `apt-get`, pnpm global installs, and
  `curl bun.sh/install | bash`. That is upstream's image recipe, not a
  system-config curl-pipe, and nothing it downloads enters `/nix/store`.
- **Docker is newly enabled on srv**, next to libvirt and `br0`. The module
  sets `ip-forward-no-drop` so Docker leaves the FORWARD policy alone. After
  the first switch, check that darkstar still reaches the LAN
  (`kubectl get nodes`, or ping a node).
- **Skills that rewrite source don't work here.** `/add-discord` and similar
  copy files into `src/` and rebuild. The code lives read-only in
  `/nix/store`. To add a channel, extend `modules/server/nanoclaw/build/` the
  same way OneCLI and Slack are applied there. The terminal (CLI) channel
  ships with core, and Slack is built in (see [Slack](#slack)).
- **Backups contain the token.** `nanoclaw-backup` dumps the vault into
  `/var/backup/nanoclaw` (root, 0700). The dump plus its encryption key
  decrypts to the Claude token, so it must only go into an encrypted backup.
  srv's restic repo is encrypted. See [Backups](#backups).

## What gets deployed

| Unit | What it does |
|------|--------------|
| `docker-network-onecli` | Creates the private `onecli` bridge network |
| `nanoclaw-onecli-env` | Renders `onecli.env.tpl` and `postgres.env.tpl` into `/run/nanoclaw-onecli/*.env` (0600, root) from the DB password, using `envsubst` at runtime |
| `docker-onecli-postgres` | The vault's PostgreSQL (no host port) |
| `docker-onecli` | OneCLI 1.42.0, digest-pinned. It's exactly the version NanoClaw's `add-onecli` skill sanctions: 1.42.0 closes a credential-injection bypass, and 1.43+ is unsupported. API on `127.0.0.1:10254`, proxy on `127.0.0.1:10255` |
| `docker-onecli-gateway` | socat relay: the only thing on the agents' `--internal` network (`host.docker.internal:10255`) |
| `nanoclaw-vault-sync` | Pushes the setup-token into the vault as secret `Anthropic` (creates it, or PATCHes the value on later runs) |
| `nanoclaw-agent-image` | Builds `nanoclaw-agent-v2-nanoclaw:latest`. Skips the build when the image's `org.nixos.nanoclaw.source` label already matches the package |
| `nanoclaw` | The host: `node dist/index.js` as user `nanoclaw`, working dir `/var/lib/nanoclaw`. Its start step assembles `.env` in `/run/nanoclaw` (non-secret settings, plus the Slack tokens when enabled) |
| `nanoclaw-backup` (timer, 02:45) | Consistent dumps of the vault and central DB into `/var/backup/nanoclaw`, ahead of srv's 03:00 restic run |

Operator commands, all run as the `nanoclaw` user via sudo:

| Command | Purpose |
|---------|---------|
| `nanoclaw-init-cli-agent` | Creates the owner and first agent, wired to the terminal channel |
| `nanoclaw-chat` | Sends a message through the terminal channel |
| `nanoclaw-ncl` | Upstream's admin CLI (`ncl groups list`, …) |
| `nanoclaw-check-agent-creds` | Proves no raw credential exists inside running agent containers |
| `nanoclaw-slack-wire` | (Slack on) Validates the bot token, opens your DM with the bot, and creates the owner and first agent wired to it |

The build is NanoClaw at a pinned rev (`settings/versions.nix` →
`server.nanoclaw`). The Nix derivation reproduces the `nc:` directives of two
upstream skills, `add-onecli` and `add-slack`:

- it copies their files: OneCLI's from its in-tree payload, Slack's from
  upstream's `channels` branch, pinned as `server.nanoclaw-channels`;
- it applies their registration imports;
- it adds `@onecli-sh/sdk@2.2.1` and `@chat-adapter/slack@4.29.0` to
  package.json and the lockfile (`build/skills.patch`).

Then it runs upstream's `pnpm install --frozen-lockfile` and `pnpm run build`,
and compiles better-sqlite3 from source. The Slack adapter stays inert
(`Channel credentials missing, skipping channel="slack"`) until its tokens
exist.

## Provision the secrets

Two 1Password items are needed for the core service, and two more for Slack.
Each lives in the `nixerator` vault with a `credential` field. The core
`op://` references are already in `secrets.json.tpl` under `nanoclaw`, so
`just render-secrets` fails until those two items exist. Do this on a
workstation. Never paste a value into the chat or onto a command line.

| Item | JSON key | Needed for |
|------|----------|------------|
| `nanoclaw-claude-token` | `nanoclaw.claudeToken` | core |
| `nanoclaw-onecli-db-password` | `nanoclaw.onecliDbPassword` | core |
| `clanky-slack-app`, field `Bot-User-Oauth-Token` | `nanoclaw.slackBotToken` | Slack |
| `clanky-slack-app`, field `Default-clanky-App-Token` | `nanoclaw.slackAppToken` | Slack |

1. **Generate the Claude setup-token.** It needs a browser, so run it on
   qbert:

   ```bash
   claude setup-token
   ```

   Sign in with the Pro/Max account. It prints one `sk-ant-oat01-…` line.
   Leave the terminal open. (Running it over SSH on srv also works
   `[Likely]`: it prints a URL you can open on any device.)

2. **Store the token in 1Password.** Create the item in the 1Password app and
   paste the token into its `credential` field, so it never touches the shell
   or the chat.

3. **Create the OneCLI database password.** Create the
   `nanoclaw-onecli-db-password` item in the 1Password app and use its
   password generator for the `credential` field (64 hex-safe characters
   work). The value never needs to be seen.

   The two Slack items are not in `secrets.json.tpl` yet, so
   `just render-secrets` does not need them. Add them when you have the tokens
   (Slack section).

4. **Render, push and rebuild:**

   ```bash
   just render-secrets            # on the workstation
   render-secrets --push srv      # copy secrets.json to srv
   # then on srv:
   just qr
   ```

The plaintext exists only in `secrets.json` (0600, outside the repo and the
store) and at `/run/nanoclaw-secrets/<name>` (tmpfs, root 0400).

## Keep spend capped: leave extra usage off

The subscription's included usage is the only thing this should spend. In
claude.ai, check that **extra usage / usage credits is OFF** (Settings →
Usage; exact label `[Guessing]`, the UI moves). With it off, requests past the
included allowance pause instead of billing overages. Nothing in this module
can turn it on: the vault holds an OAuth token, not an API key, and the sync
refuses anything that isn't `sk-ant-oat…`.

Monthly Agent SDK credit, as you reported it: Pro $20, Max 5x $100, Max 20x
$200. A 24/7 assistant can use up Pro's $20 quickly, so on Pro expect pauses
near the end of the month.

## First run

```bash
# 1. Everything up?
systemctl status nanoclaw docker-onecli docker-onecli-gateway nanoclaw-vault-sync nanoclaw-agent-image
journalctl -u nanoclaw -b | grep -E 'Gateway provider selected|Session runtime driver selected|NanoClaw running'

# 2. Agent image present, and built from the running package?
journalctl -u nanoclaw-agent-image -b | tail -3
docker image inspect nanoclaw-agent-v2-nanoclaw:latest \
  --format '{{index .Config.Labels "org.nixos.nanoclaw.source"}}'

# 3. Vault holds an OAuth-mode secret (metadata only, no value is ever returned)
curl -s http://127.0.0.1:10254/v1/secrets | jq '.[] | {name, type, metadata}'
#   -> {"name":"Anthropic","type":"anthropic","metadata":{"authMode":"oauth"}}

# 4. Owner + first agent on the terminal channel (once)
nanoclaw-init-cli-agent --display-name Dustin --agent-name Andy

# 5. Talk to it
nanoclaw-chat "Say hello and tell me which model you are"

# 6. While that session's container is alive (it idles out after a while):
nanoclaw-check-agent-creds
#   CLAUDE_CODE_OAUTH_TOKEN=placeholder
#   OK:   no sk-ant- value in the environment
#   OK:   no sk-ant- credential anywhere on the container filesystem
```

The first `nanoclaw-agent-image` run takes a few minutes. The host starts
without waiting for it (`Wants=`, not `Requires=`), and the unit retries on
failure. The OneCLI dashboard is loopback-only. From your desktop run
`ssh -N -L 127.0.0.1:10254:127.0.0.1:10254 srv`, then open
<http://127.0.0.1:10254>. Use that exact origin and local port: the module sets
OneCLI's `APP_URL` to `http://127.0.0.1:10254`, and OAuth redirects and the
connect links agents hand out are built from it. Keep the tunnel on loopback and
close it when done, because the API has no auth in local mode.

## Re-auth (token revoked or expired)

Anthropic can revoke setup-tokens after account-level auth events (observed
Sept 2026). The symptom is agents erroring with 401s in `journalctl -u nanoclaw`
and `docker logs onecli`. To recover:

1. `claude setup-token` on a workstation (step 2 above).
2. Update the `credential` field of the `nanoclaw-claude-token` item.
3. `just render-secrets`, push to srv, then on srv `just qr` (the activation
   script rewrites `/run/nanoclaw-secrets/claude-token`).
4. Restart the sync: `sudo systemctl restart nanoclaw-vault-sync`. It PATCHes
   the existing `Anthropic` secret in place (same id, so per-agent grants
   survive). Restarting the sync also restarts `nanoclaw`.

A rotated value changes no store path, so a rebuild alone never restarts the
units. The restart in step 4 is required.

## Slack

A personal workspace (not a work one) in Socket Mode: srv opens an outbound
WebSocket to Slack, so nothing on srv is public. The two tokens are
1Password items with their own gate. NanoClaw runs terminal-only until both
keys are in `secrets.json`, and evaluation warns until then.

**1. Create the app** at api.slack.com/apps → Create New App → From scratch,
in your personal workspace:

- **OAuth & Permissions → Bot Token Scopes:** `chat:write`, `im:write`,
  `channels:history`, `groups:history`, `im:history`, `channels:read`,
  `groups:read`, `mpim:read`, `mpim:write`, `mpim:history`, `users:read`,
  `reactions:write`, `files:read`, `files:write`. Slack adds `app_mentions:read`
  itself when you subscribe to `app_mention`. The canvas scopes
  (`canvases:read`, `canvases:write`) are in upstream's full list but optional;
  Slack may hide them on a free workspace.
- **App Home:** enable the Messages Tab, and tick "Allow users to send Slash
  commands and messages from the messages tab".
- **Basic Information → App-Level Tokens:** generate one with
  `connections:write`. This is the `xapp-…` token.
- **Socket Mode:** on.
- **Event Subscriptions:** on. Add bot events `message.im` (required for DMs),
  `message.channels`, `message.groups`, `message.mpim`, `app_mention`,
  `member_joined_channel` and `member_left_channel`. Click **Save Changes**,
  then reinstall the app when Slack asks. No Request URL is needed.
- **Install to Workspace**, then copy the Bot User OAuth Token (`xoxb-…`).
- **Your member ID:** Profile → ⋮ → Copy member ID (`U…`).

These steps are the upstream skill's own, from `.claude/skills/add-slack/SKILL.md`.

**2. Store the tokens** in the `nixerator` vault. The `clanky-slack-app` item
holds the bot token (xoxb-…) in `Bot-User-Oauth-Token` and the app-level token
(xapp-…, scope `connections:write`) in `Default-clanky-App-Token`. The template
already references both. Run `render-secrets --push srv` from a checkout that
has this template, then `just qr` on srv.

**3. Check it connected, then wire yourself:**

```bash
journalctl -u nanoclaw -b | grep -i slack     # no "invalid_auth", no "credentials missing"
nanoclaw-slack-wire --member-id U0123456789 --display-name Dustin --agent-name clanky
```

`nanoclaw-slack-wire` does three things:

- checks the bot token (`auth.test`);
- opens the bot↔you DM (`conversations.open`; a failure here means `im:write`
  is missing, so add it and reinstall the app);
- creates you as owner, plus a first agent wired to that DM.

Then DM the bot in Slack.

**The bot sends but never answers.** The welcome DM arrives, but your replies
get no response and the host log shows no inbound Slack message. Slack is not
delivering events. Check, in this order: `message.im` is in the bot events and
saved, the app was reinstalled after the change, the Messages Tab is on in App
Home, and Socket Mode is on. The bot token stays the same across a reinstall,
so no secret needs re-rendering.

**Where the tokens live.** They are only in `/run/nanoclaw/nanoclaw.env`
(tmpfs, 0600, the `nanoclaw` user), rendered from `host-secrets.env.tpl` at
every service start. NanoClaw reads them from `.env` only, never from the
process environment, so agent containers never see them. The start step
refuses anything that isn't `xoxb-` / `xapp-` shaped.

**Rotating them.** Update the 1Password item, `just render-secrets`, push to
srv, `just qr`, then `sudo systemctl restart nanoclaw`. The restart re-renders
`.env`.

**Channels other than your DM.** Anything in a channel the bot is in becomes
input to the agent, including text posted by other integrations. Invite the
bot only where you want it, and wire each channel deliberately
(`nanoclaw-ncl wirings create …`, see upstream's `/manage-channels`).

## Adding integrations

Order of preference, cheapest first. Sources: upstream's
[extend overview](https://docs.nanoclaw.dev/extend/overview) and
[tools](https://docs.nanoclaw.dev/extend/tools) pages, checked 2026-10-21.

1. **MCP server per agent group (runtime, no rebuild).** On srv:

   ```bash
   nanoclaw-ncl groups list                       # find the group id
   nanoclaw-ncl groups config add-mcp-server --id <group-id> --name <name> \
     --command npx --args '["-y", "<package>"]' --env '{}'
   nanoclaw-ncl groups restart --id <group-id>
   ```

   A remote Streamable HTTP server uses `--url https://…` instead of
   `--command`. Never put a key in `--env` or `--headers`: connect the service
   in the OneCLI vault (web UI on `127.0.0.1:10254`) and let the gateway inject
   the credential. Agents have no access to a vault secret until it is granted.
2. **Per-group skills and instructions.** Files under the group's folder in
   `/var/lib/nanoclaw/groups/<folder>/`. Not yet managed from Nix.
3. **CLIs in the agent image.** Either the per-group `packages_apt` /
   `packages_npm` settings (packages only), or a layered Dockerfile `FROM` the
   image `nanoclaw-agent-v2-nanoclaw:latest`, built by a new unit beside
   `nanoclaw-agent-image`. Not built yet.
4. **New channels or providers (code-carrying).** Extend `build/` the way the
   Slack skill is wired: new `nc:copy` files in `build/default.nix`, a
   regenerated `skills.patch`, then refresh `hash` and `pnpmDepsHash`. Never
   install by merging an upstream branch, and skip `/update-skills`: the version
   pin in `settings/versions.nix` is the upgrade path.

Known gaps as of 2026-10-21: Gmail and Google Calendar are not on upstream's
trunk (`/add-gmail-tool` and `/add-gcal-tool` were removed), so email reading
means a third-party Gmail MCP server. `/add-resend` is an email channel through
Resend. Port 3000 (the Slack webhook route) listens on all interfaces but is
blocked by the firewall; it is unused in Socket Mode.

## Backups

`nanoclaw-backup.timer` (02:45) writes three files to `/var/backup/nanoclaw`
(root, 0700):

- `onecli-postgres.sql.gz` (pg_dump);
- `onecli-app-data.tar`, the vault volume, including `secret-encryption-key`;
- `nanoclaw-v2.db`, an online SQLite backup of the central DB.

srv's restic job (03:00) backs up that directory together with
`/var/lib/nanoclaw` (agent groups and memory, session DBs). The `.env` symlink
points into `/run`, and restic stores the link, not the tokens.

Tested in the sandbox: the dump restored into a fresh Postgres plus a fresh
app-data volume brought back the `Anthropic` secret.

**Restore** (on a rebuilt srv; the vault's Postgres container stays up, the
vault app and host are stopped):

```bash
sudo systemctl stop nanoclaw docker-onecli    # docker-onecli-postgres keeps running
# app-data: unpack into the volume
docker run --rm -v onecli_app-data:/app -v /path/to/restore:/b:ro postgres:18-alpine \
  sh -c 'tar -xf /b/onecli-app-data.tar -C /app --strip-components=1'
# postgres: load the dump into the running DB container
zcat /path/to/restore/onecli-postgres.sql.gz | docker exec -i onecli-postgres psql -q -U onecli -d onecli
# central DB + groups: restic-restore /var/lib/nanoclaw, then:
sudo install -o nanoclaw -g nanoclaw -m 0640 /path/to/restore/nanoclaw-v2.db /var/lib/nanoclaw/data/v2.db
sudo systemctl start docker-onecli nanoclaw
```

## Rotate the OneCLI DB password

`POSTGRES_PASSWORD` only seeds a fresh volume. To change it on a live vault:

```bash
NEW=$(openssl rand -hex 32)
# via stdin, so the password never shows up in `ps`
printf "ALTER USER onecli PASSWORD '%s';\n" "$NEW" | docker exec -i onecli-postgres psql -U onecli -d onecli
# put $NEW in the nanoclaw-onecli-db-password item (op item edit, blind), then
unset NEW
# just render-secrets, push to srv, just qr on srv, then:
sudo systemctl restart nanoclaw-onecli-env docker-onecli
```

## Why no secret reaches /nix/store

- **Nix handles paths, never values.** `claudeTokenFile` and
  `onecli.dbPasswordFile` are `/run/nanoclaw-secrets/…` strings. Nothing calls
  `readFile` on them or interpolates their contents, and assertions reject a
  `/nix/store` path.
- **Units read the secrets through `LoadCredential=` at runtime.** The vault
  sync runs as a `DynamicUser` and sends the token file through
  `jq --rawfile` to curl's stdin and then the vault. It never appears in argv,
  an environment variable, a log line, or the host's `.env`.
- **The only rendered secret file is `/run/nanoclaw-onecli/*.env`** (tmpfs,
  0600, root). It is produced by `envsubst` in a oneshot unit, from
  placeholder-only templates checked into git. Nothing renders at eval or
  build time.
- **The host `.env` is assembled at runtime in `/run/nanoclaw`** (tmpfs,
  0600). Its non-secret half comes from a store file (gateway URL, image
  names, TZ). The Slack tokens are appended from `host-secrets.env.tpl` by
  the unit's start step, reading them via `LoadCredential`. The Claude token
  is never in it: that is the point of the gateway.
- **Eval sees key names, never values.** `hosts/srv/modules.nix` only asks
  whether a `nanoclaw.*` key exists in `secrets.json`, to gate the service.
- **Checked:** test systems built from this module were grepped across their
  whole closures, with zero hits. They used a fake Claude token, a random DB
  password and fake Slack tokens, with a full live run in a sandbox. Repeat on
  srv with the real values:

  ```bash
  for s in /run/nanoclaw-secrets/*; do
    nix-store -qR /run/current-system | xargs sudo grep -rlF -f "$s" 2>/dev/null
  done
  # no output = no secret is in the store
  ```

## Upgrading

- **NanoClaw:** bump `version` (a release tag, `v<version>`) in `settings/versions.nix` (`updatePolicy = "manual"`). Releases are upstream's `stable` channel; read the release's `[BREAKING]` lines first. 2026.10.0, for example, required the OneCLI 1.42.0 move.
  Then rebuild `build/skills.patch`: in a checkout at the new rev, append the
  two registration imports and run
  `pnpm add @onecli-sh/sdk@<pin> @chat-adapter/slack@<pin> --ignore-scripts`,
  then diff `package.json`, `pnpm-lock.yaml`,
  `src/gateway-providers/installed.ts` and `src/channels/index.ts`. Refresh
  `hash` and `pnpmDepsHash` from the build's hash-mismatch errors. Bump
  `nanoclaw-channels` alongside it: the Slack adapter compiles against core,
  so `tsc` failing is the signal they drifted. Read upstream's `CHANGELOG.md` first: major
  versions are breaking rewrites. Migrations run automatically on host start.
  The preStart stamps upstream's upgrade marker, because a NixOS rebuild is
  this install's sanctioned upgrade path.
- **OneCLI:** match the `onecli-gateway` pin exactly, never newer (1.43+
  breaks credential assignment as of NanoClaw 2026.10.0). Follow the pin in upstream's
  `.claude/skills/add-onecli/versions.json` and upstream's
  `docs/onecli-upgrades.md` (it is in the package). A 2.x gateway uses
  a different (split) compose layout, so it is not a one-line image bump.
