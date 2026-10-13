# NanoClaw on srv

NanoClaw ([nanocoai/nanoclaw](https://github.com/nanocoai/nanoclaw)) is a
personal AI assistant. It runs as one Node.js host process that starts one
Docker container per agent session. srv runs it declaratively through
`server.nanoclaw` (`modules/server/nanoclaw/`). It authenticates with the
Claude **subscription** via a `claude setup-token` OAuth token, never an API
key. The credential lives in the **OneCLI Agent Vault**, and agent containers
only ever see `CLAUDE_CODE_OAUTH_TOKEN=placeholder`.

## Read first: caveats and deviations

- **agenix is new to this repo, scoped to this one service.** The rest of
  nixerator stays on 1Password (`extras/docs/secrets.md`,
  `extras/docs/secrets-agenix-evaluation.md`). The agenix module is loaded on
  srv only (`flake.nix`, `extraModules`), and only `secrets/nanoclaw-*.age`
  use it.
- **The service stays off until you create both `.age` files.** Until then,
  srv builds normally and evaluation prints a warning.
- **This is not upstream's topology.** Upstream publishes OneCLI's admin API
  and proxy on docker0. Under egress lockdown it attaches the whole OneCLI
  container to the agents' network. On OneCLI 1.41.0 that API is
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
- **Skills that rewrite source don't work here.** `/add-telegram`,
  `/add-slack` and similar copy files into `src/` and rebuild. The code lives
  read-only in `/nix/store`. To add a channel, extend
  `modules/server/nanoclaw/build/` the same way the OneCLI skill is applied
  there. The terminal (CLI) channel ships with core and works as-is.
- **Backups.** srv's restic job covers `/srv/nfs` only. NanoClaw state lives in
  `/var/lib/nanoclaw` and the Docker volumes `onecli_pgdata` and
  `onecli_app-data`. `onecli_app-data` holds the vault's encryption key: lose
  it and the vault is unreadable.

## What gets deployed

| Unit | What it does |
|------|--------------|
| `docker-network-onecli` | Creates the private `onecli` bridge network |
| `nanoclaw-onecli-env` | Renders `onecli.env.tpl` and `postgres.env.tpl` into `/run/nanoclaw-onecli/*.env` (0600, root) from the agenix DB password, using `envsubst` at runtime |
| `docker-onecli-postgres` | The vault's PostgreSQL (no host port) |
| `docker-onecli` | OneCLI 1.41.0 (digest-pinned; the version NanoClaw's `add-onecli` skill sanctions). API on `127.0.0.1:10254`, proxy on `127.0.0.1:10255` |
| `docker-onecli-gateway` | socat relay: the only thing on the agents' `--internal` network (`host.docker.internal:10255`) |
| `nanoclaw-vault-sync` | Pushes the agenix setup-token into the vault as secret `Anthropic` (creates it, or PATCHes the value on later runs) |
| `nanoclaw-agent-image` | Builds `nanoclaw-agent-v2-nanoclaw:latest`. Skips the build when the image's `org.nixos.nanoclaw.source` label already matches the package |
| `nanoclaw` | The host: `node dist/index.js` as user `nanoclaw`, working dir `/var/lib/nanoclaw` |

Operator commands, all run as the `nanoclaw` user via sudo:

| Command | Purpose |
|---------|---------|
| `nanoclaw-init-cli-agent` | Creates the owner and first agent, wired to the terminal channel |
| `nanoclaw-chat` | Sends a message through the terminal channel |
| `nanoclaw-ncl` | Upstream's admin CLI (`ncl groups list`, …) |
| `nanoclaw-check-agent-creds` | Proves no raw credential exists inside running agent containers |

The build is NanoClaw at a pinned rev (`settings/versions.nix` → `server.nanoclaw`). The Nix
derivation reproduces the `add-onecli` skill's `nc:` directives: it copies the
payload, applies the registration import, and adds `@onecli-sh/sdk@2.2.1` to
package.json and the lockfile (`build/onecli-gateway.patch`). Then it runs
upstream's `pnpm install --frozen-lockfile` and `pnpm run build`, and compiles
better-sqlite3 from source.

## Provision the secrets

You need two agenix payloads. Do this on a workstation.

1. **Get srv's host key.** agenix decrypts at activation with this key:

   ```bash
   SRV_KEY=$(ssh srv cat /etc/ssh/ssh_host_ed25519_key.pub)
   ```

   Paste it (and optionally your own key) into `secrets/secrets.nix` so the
   `agenix` CLI knows the recipients.

2. **Generate the Claude setup-token.** It needs a browser, so run it on
   qbert or donkeykong:

   ```bash
   claude setup-token
   ```

   Sign in with the Pro/Max account. It prints one `sk-ant-oat01-…` line.
   Leave the terminal open. (Running it over SSH on srv also works
   `[Likely]`: it prints a URL you can open on any device.)

3. **Encrypt the token without it touching disk or shell history.** `age`
   reads the plaintext from stdin:

   ```bash
   cd ~/git/nixerator
   nix shell nixpkgs#age -c age -r "$SRV_KEY" -o secrets/nanoclaw-claude-token.age
   # paste the sk-ant-oat01-… token, press Enter, then Ctrl-D
   ```

   With your key in `secrets/secrets.nix` you can use agenix instead:
   `cd secrets && nix run github:ryantm/agenix -- -e nanoclaw-claude-token.age`.

4. **Create the OneCLI database password.** It is never displayed:

   ```bash
   openssl rand -hex 32 | nix shell nixpkgs#age -c age -r "$SRV_KEY" -o secrets/nanoclaw-onecli-db-password.age
   ```

5. **Track the files, then rebuild srv.** Flakes only see tracked files:

   ```bash
   git add secrets/nanoclaw-claude-token.age secrets/nanoclaw-onecli-db-password.age secrets/secrets.nix
   # commit + push, then on srv:
   just qr
   ```

The `.age` files are ciphertext, so they are safe in git and in the store.
The plaintext only ever exists at `/run/agenix/<name>` (tmpfs, root 0400).

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
failure. The OneCLI dashboard is loopback-only: `ssh -L 10254:127.0.0.1:10254 srv`,
then open <http://localhost:10254>.

## Re-auth (token revoked or expired)

Anthropic can revoke setup-tokens after account-level auth events (observed
Sept 2026). The symptom is agents erroring with 401s in `journalctl -u nanoclaw`
and `docker logs onecli`. To recover:

1. `claude setup-token` on a workstation (step 2 above).
2. Replace the payload. Overwriting with `age -r "$SRV_KEY" -o secrets/nanoclaw-claude-token.age`
   works; the old ciphertext just gets replaced.
3. Commit, push, then on srv `just qr`. The re-encrypted `.age` has a new
   store path, which is wired into `nanoclaw-vault-sync`'s restart triggers.
   The switch re-runs the sync, which PATCHes the existing `Anthropic` secret
   in place (same id, so per-agent grants survive). Restarting the sync also
   restarts `nanoclaw`.
4. If you only re-deployed without changing the file, force it:
   `sudo systemctl restart nanoclaw-vault-sync`.

## Rotate the OneCLI DB password

`POSTGRES_PASSWORD` only seeds a fresh volume. To change it on a live vault:

```bash
NEW=$(openssl rand -hex 32)
# via stdin, so the password never shows up in `ps`
printf "ALTER USER onecli PASSWORD '%s';\n" "$NEW" | docker exec -i onecli-postgres psql -U onecli -d onecli
printf '%s\n' "$NEW" | age -r "$SRV_KEY" -o secrets/nanoclaw-onecli-db-password.age
unset NEW
# commit, push, just qr on srv, then:
sudo systemctl restart nanoclaw-onecli-env docker-onecli
```

## Why no secret reaches /nix/store

- **Nix handles paths, never values.** `claudeTokenFile` and
  `onecli.dbPasswordFile` are `/run/agenix/…` strings. Nothing calls
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
- **The host `.env` is a store file on purpose.** It contains no credential
  (gateway URL, image names, TZ). That is the point of the gateway:
  NanoClaw's host never holds the token.
- **The `.age` files do enter the store, as ciphertext.** That is agenix's
  normal model.
- **Checked:** a test system built from this module (fake token, random
  password, full live run in a sandbox) was grepped across all 662 closure
  paths for both values, with zero hits. Repeat on srv with the real values:

  ```bash
  nix-store -qR /run/current-system | xargs sudo grep -rlF -f /run/agenix/nanoclaw-claude-token 2>/dev/null
  # no output = the token is not in the store
  ```

## Upgrading

- **NanoClaw:** bump `rev` in `settings/versions.nix` (`updatePolicy = "manual"`).
  Rebase `build/onecli-gateway.patch` (`pnpm add @onecli-sh/sdk@<pin> --ignore-scripts`
  in a checkout, then diff), then refresh `hash` and `pnpmDepsHash` from the
  build's hash-mismatch errors. Read upstream's `CHANGELOG.md` first: major
  versions are breaking rewrites. Migrations run automatically on host start.
  The preStart stamps upstream's upgrade marker, because a NixOS rebuild is
  this install's sanctioned upgrade path.
- **OneCLI:** follow the `onecli-gateway` pin in upstream's
  `.claude/skills/add-onecli/versions.json` and upstream's
  `docs/onecli-upgrades.md` (it is in the package). A 2.x gateway uses
  a different (split) compose layout, so it is not a one-line image bump.
