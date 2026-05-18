# 1Password secrets — design

Issue: [#61](https://github.com/bashfulrobot/nixerator/issues/61) — "Assess using 1Password instead of git-crypt".

Branch: `feat/61-assess-using-1password-instead-of-git-cryp`.

## Background

Today, `secrets/secrets.json` is a single JSON blob holding every credential and topology value the flake uses (API tokens, restic creds, Syncthing IDs, Tailscale IPs, etc.). It is git-crypt encrypted via `.gitattributes` filters and decrypted in-place when the repo is unlocked. A second file, `modules/system/ssh/default.nix`, is also git-crypted.

The flake reads the JSON once in `flake.nix:134-138` and passes the resulting attrset as `specialArgs.secrets` to every module. Modules consume it inline (`secrets.kong.kongKonnectPAT`, etc.) — those values get baked into derived config files in `/nix/store`.

The user uses Claude Code (and other AI assistants) inside this repo. The risk: once the repo is unlocked for any reason, every plaintext credential sits in `secrets/secrets.json`, where a default recursive read by an AI session can ingest it. The user explicitly wants to keep secrets in `/nix/store` after build (an accepted tradeoff for a single-user system), but wants to stop having plaintext credentials sit in the working tree where AI sessions can read them.

1Password CLI (`op`) v2.34.0 is already installed system-wide.

## Goals

1. Source of truth for every credential lives in 1Password.
2. git-crypt removed entirely (filters, key file, helper script, bootstrap step).
3. Plaintext secrets never sit in the repo working tree.
4. Existing inline `secrets.foo.bar` pattern in Nix modules is preserved. No callsite refactors.

## Non-goals

- Removing credentials from `/nix/store`. The user accepts this in the issue body. Solving that would require activation-time materialisation (opnix system-mode or sops-nix), which needs a 1Password service account — not available on the user's personal-only 1P plan.
- Hardening against an actively-malicious AI process that probes `/run/user/$UID/` during a rebuild. The threat model is accidental disclosure from broad-strokes repo reads, not targeted exfiltration.
- Removing `op` from the rebuild path. Every rebuild requires an active `op` session (one Touch ID).
- Centralising other host secrets (e.g., the opnix service-account token) that the issue does not call out.
- Moving the existing binary blobs in `secrets/` (`init.png`, `sg.png`, `yasd-export-2026-3-4-v3.json`) out of git-crypt. They are not credentials. Out of scope for this issue; can be revisited when removing the last git-crypt filter.

## Approach

Render the secrets JSON via `op inject` into a short-lived tmpfs file (`/run/user/$UID/`, mode 600), pass its path to Nix via the `NIXERATOR_SECRETS` env var, run the rebuild, then `shred -u` the file. The flake reads from `getEnv "NIXERATOR_SECRETS"` instead of `./secrets/secrets.json`. The committed source of secrets is a template (`secrets/secrets.json.tpl`) containing only `op://Personal/Item/field` locators.

Why this shape:
- Locators are not credentials. The working tree no longer contains anything an AI session can exfiltrate as a usable secret.
- The rendered plaintext lives outside the repo, in tmpfs, for the duration of one `nixos-rebuild` invocation.
- `flake.nix` keeps its `builtins.fromJSON (builtins.readFile …)` shape. Every existing `secrets.foo.bar` callsite — across `flake.nix`, `modules/system/nix/default.nix`, `mcp-servers.nix`, `syncthing/default.nix`, `clay/default.nix`, `dorkos/default.nix`, `todoist-cli/default.nix`, `caddy/default.nix`, `claude-code/default.nix`, `agent-scan/default.nix`, `zed/default.nix`, and all three host `modules.nix` files — keeps working without modification.
- No 1Password service account required. Works with a personal 1Password account via interactive `op signin`.

Approaches considered and rejected:

| Approach | Failing goal | Why |
|---|---|---|
| `op inject` writing to `secrets/secrets.json` (gitignored) | 3 | Plaintext file sits inside the repo working tree once rendered. Default AI recursive read hits it. Deny-rules are policy-only and Bash can route around them. |
| opnix system-mode (activation-time `/run/secrets/*`) | dependency | Requires 1P service account (Business/Teams). User is on personal plan. |
| direnv + `op` + `builtins.getEnv` per callsite | 4 | Every `secrets.foo.bar` becomes `builtins.getEnv "FOO"`. Touches every module. |
| Hybrid (opnix Home-Manager + tiny op-inject for boot-critical) | 3, 4 | Still requires plaintext on disk for the system-level remnant. Adds a second mechanism for marginal gain. |

## Detailed design

### File touches

| File | Change |
|---|---|
| `secrets/secrets.json.tpl` | **New.** JSON with the existing schema, every leaf value replaced by an `op://Personal/<Item>/<field>` locator. Committed. |
| `secrets/secrets.json` | **Deleted from git** (git-crypt removed). The path no longer exists after this change — neither in plaintext nor in git history past the cutover commit. |
| `.gitattributes` | Remove the two `filter=git-crypt diff=git-crypt` lines. |
| `.git-crypt/` | **Delete.** Whole directory removed (GPG users, key collaborators). |
| `flake.nix:134-138` | Replace `secretsFile = "${self}/secrets/secrets.json"` block with the `getEnv "NIXERATOR_SECRETS"` pattern below. |
| `justfile` | Add `rebuild` recipe variant (or wrap existing `qr` / `dr` / `sr`) that handles signin + render + sudo + cleanup. |
| `modules/system/ssh/default.nix` | Decrypt (remove from `.gitattributes`). Refactor literal host IPs/usernames to `secrets.ssh.hosts.<name>.*` reads. |
| `extras/helpers/setup-git-crypt.sh` | **Delete.** No longer relevant. |
| `extras/docs/secrets.md` | Rewrite for the 1P flow (template syntax, `just rebuild`, signin, rotation via `op item edit`, troubleshooting). |
| `extras/docs/bootstrap.txt` | Replace "Setup git-crypt" step with "Install op + signin + render". Update key-copy instructions. |
| `.gitignore` | Add `/run/user/*/nixerator-*.json` is moot (those paths aren't under repo). No change needed, but verify `secrets/secrets.json` is also explicitly ignored to catch fat-finger renders. |
| `CLAUDE.md` topics list | Update the secrets-management bullet if one exists. (Currently none — `extras/docs/secrets.md` is referenced from the bootstrap doc, not from `CLAUDE.md`.) |

### `flake.nix` change

```nix
# before
secretsFile = "${self}/secrets/secrets.json";
secrets = builtins.fromJSON (builtins.readFile secretsFile);

# after
secretsPath = builtins.getEnv "NIXERATOR_SECRETS";
secrets =
  if secretsPath != ""
  then builtins.fromJSON (builtins.readFile secretsPath)
  else { };
```

The empty-attrset fallback lets `nix flake show`, `nix flake check`, and `nix flake metadata` succeed without an active `op` session. Every existing `secrets.foo or null` guard pattern (verified at `mcp-servers.nix:11`, `caddy/default.nix:65`, `agent-scan/default.nix:14`, `todoist-cli/default.nix:14`, `dorkos/default.nix:77`, `claude-code/default.nix:97`, `zed/default.nix:303`) already handles the missing-secrets case gracefully — those modules emit a no-op for the secret-dependent feature instead of failing eval. Modules that dereference secrets unconditionally (`syncthing/default.nix`, `hosts/*/modules.nix` restic blocks, `system/nix/default.nix` access-tokens) will throw a clear "attribute missing" error on a no-secrets eval, which is the correct behaviour: do not silently build a broken system.

### `secrets/secrets.json.tpl` schema

Mirror the existing schema verbatim. Every leaf string is replaced with an `op://Personal/<item>/<field>` locator. New top-level `ssh.hosts` block holds the LAN topology lifted out of `modules/system/ssh/default.nix`.

```json
{
  "github": {
    "accessToken": "op://Personal/Nixerator GitHub PAT/token"
  },
  "kong": {
    "kongKonnectPAT": "op://Personal/Nixerator Kong Konnect/pat"
  },
  "context7": {
    "apiKey": "op://Personal/Nixerator Context7/api-key"
  },
  "clay": {
    "pin": "op://Personal/Nixerator Clay/pin"
  },
  "claudito": {
    "username": "op://Personal/Nixerator Claudito/username",
    "password": "op://Personal/Nixerator Claudito/password"
  },
  "syncthing": {
    "gui": {
      "user": "op://Personal/Nixerator Syncthing GUI/user",
      "password": "op://Personal/Nixerator Syncthing GUI/password"
    }
  },
  "qbert": {
    "tailscale_ip": "op://Personal/Nixerator Host qbert/tailscale-ip",
    "syncthing_id": "op://Personal/Nixerator Host qbert/syncthing-id"
  },
  "donkey-kong": {
    "tailscale_ip": "op://Personal/Nixerator Host donkey-kong/tailscale-ip",
    "syncthing_id": "op://Personal/Nixerator Host donkey-kong/syncthing-id"
  },
  "restic": {
    "srv": {
      "restic_repository": "op://Personal/Nixerator restic srv/repository",
      "restic_password": "op://Personal/Nixerator restic srv/password",
      "b2_account_id": "op://Personal/Nixerator restic srv/b2-account-id",
      "b2_account_key": "op://Personal/Nixerator restic srv/b2-account-key",
      "region": "op://Personal/Nixerator restic srv/region"
    },
    "workstation": {
      "restic_repository": "op://Personal/Nixerator restic workstation/repository",
      "restic_password": "op://Personal/Nixerator restic workstation/password",
      "b2_account_id": "op://Personal/Nixerator restic workstation/b2-account-id",
      "b2_account_key": "op://Personal/Nixerator restic workstation/b2-account-key",
      "region": "op://Personal/Nixerator restic workstation/region"
    }
  },
  "gemini": {
    "apiKey": "op://Personal/Nixerator Gemini/api-key"
  },
  "snyk": {
    "token": "op://Personal/Nixerator Snyk/token"
  },
  "todoist_token": "op://Personal/Nixerator Todoist/token",
  "anthropic": {
    "apiKey": "op://Personal/Nixerator Anthropic/api-key"
  },
  "tailscale": {
    "caddyAuthKey": "op://Personal/Nixerator Tailscale caddy auth/key"
  },
  "ssh": {
    "hosts": {
      "camino": {
        "hostname": "op://Personal/Nixerator SSH camino/hostname",
        "user": "op://Personal/Nixerator SSH camino/user"
      },
      "budgie": {
        "hostname": "op://Personal/Nixerator SSH budgie/hostname"
      },
      "feral": {
        "hostname": "op://Personal/Nixerator SSH feral/hostname",
        "user": "op://Personal/Nixerator SSH feral/user"
      },
      "qbert_lan": "op://Personal/Nixerator Host qbert/lan-ip",
      "srv_lan": "op://Personal/Nixerator Host srv/lan-ip",
      "dk_lan": "op://Personal/Nixerator Host donkey-kong/lan-ip"
    }
  }
}
```

Naming convention: every item lives in the `Personal` vault and is prefixed `Nixerator …` so the user can grep for them in 1Password. Fields use kebab-case. Items group related values (one item per service or per host).

### `modules/system/ssh/default.nix` refactor

The current file is git-crypted and hardcodes:
- One external IP (`64.225.50.102` for camino, root user).
- One external IP via DNS (`ubuntubudgie.org`, user).
- One external IP via DNS (`prometheus.feralhosting.com`, user `msgedme`).
- Three LAN IPs (`192.168.169.2`, `192.168.168.1`, `192.168.169.3`).
- One match block keyed by raw IP (`192.168.168.1`).

After refactor: literal strings replaced by `secrets.ssh.hosts.<name>.*` reads. The match-block-keyed-by-raw-IP entry becomes `(secrets.ssh.hosts.srv_lan)` for both the key and the `hostname` field. File then dropped from the git-crypt filter in `.gitattributes`. The post-decrypt file contains no sensitive literals.

### `justfile` `rebuild` recipe

The existing recipes are `qr` (qbert rebuild), `dr` (donkeykong rebuild), `sr` (srv rebuild). These get a shared pre-step that handles signin, render, env passthrough, and cleanup.

```just
# Render secrets template via op inject into a short-lived tmpfs file.
# Echoes the path on stdout so callers can capture and trap-cleanup.
_render-secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! op whoami >/dev/null 2>&1; then
        eval "$(op signin)"
    fi
    rendered=$(mktemp -p /run/user/$(id -u) nixerator-XXXXXX.json)
    chmod 600 "$rendered"
    op inject -i secrets/secrets.json.tpl -o "$rendered"
    echo "$rendered"

# Wrapper around an existing rebuild recipe (qr/dr/sr) that renders, runs, cleans up.
# Usage: just rebuild qbert
rebuild host:
    #!/usr/bin/env bash
    set -euo pipefail
    rendered=$(just _render-secrets)
    trap 'shred -u "$rendered" 2>/dev/null || rm -f "$rendered"' EXIT
    sudo --preserve-env=NIXERATOR_SECRETS \
        NIXERATOR_SECRETS="$rendered" \
        nixos-rebuild switch --impure --flake ".#{{host}}"
```

The existing per-host recipes (`qr`, `dr`, `sr`) get a thin shim that delegates to `rebuild <host>`. The remote-rebuild paths (where one host kicks off a rebuild on another) need the same shim — they render locally, then `ssh target "NIXERATOR_SECRETS=... sudo nixos-rebuild switch ..."` is replaced by a remote variant that scp's the rendered file to the target's `/run/user/$UID/` and triggers the rebuild there. (Confirm scope by reading the existing `remote-rebuild` recipes during implementation.)

### Bootstrap on a new machine

Update `extras/docs/bootstrap.txt`. The relevant section becomes:

```bash
# Step 4 (was: Setup git-crypt) — Install op CLI, sign in, render secrets, first rebuild.
nix-shell -p _1password-cli --run "op signin"          # interactive; account add then biometric
cd "$TARGET_REPO_PATH"
just rebuild "$TARGET_HOST"                            # renders + sudo nixos-rebuild
```

The `~/.ssh/nixerator-git-crypt-key` copy step is removed. The GPG-keys copy step stays — GPG keys are still needed for git commit signing, just not for git-crypt.

### AI-leak posture

| Surface | State after change |
|---|---|
| Repo working tree | Contains `secrets/secrets.json.tpl` with `op://Personal/…` locators. No credentials. |
| `secrets/secrets.json` | Does not exist. Path-not-found on any read attempt. |
| Git history | git-crypt-encrypted blobs in old commits stay encrypted forever (the key is destroyed during cutover, see Migration). New history forward contains only template. |
| Rendered tmpfs file | `/run/user/$UID/nixerator-XXXXXX.json`, mode 600, exists for the ~5 seconds of one `nixos-rebuild` invocation, shredded on exit. Outside the repo working tree. |
| `/nix/store` | Contains derived config files with credentials baked in (e.g., the MCP server JSON). Accepted tradeoff per the issue. |
| `op` session | One Touch ID per `just rebuild`. Session ends when the script exits or shell closes. No long-lived session. |

The default behaviour of "AI assistant reads repo files" yields zero usable credentials. An AI session that specifically reads `/run/user/$UID/nixerator-XXXXXX.json` during a concurrent rebuild could exfiltrate the rendered set, but this requires the AI to be (a) running concurrently with a rebuild and (b) probing outside the repo working tree — a different threat model than the one the issue calls out.

### Migration plan

Cutover in a single PR. The git-crypt-encrypted history stays — encrypted blobs in old commits cannot be retroactively decrypted without the key, and the key gets destroyed as part of this PR.

1. Populate the 1Password items per the schema above. Source values are the current contents of `secrets/secrets.json` plus the literals in `modules/system/ssh/default.nix`. (Manual step; do this before the cutover commit.)
2. Test-render locally: `op inject -i secrets/secrets.json.tpl -o /tmp/test.json` and diff against the current `secrets/secrets.json`. Confirm structural match.
3. Run `just rebuild qbert` (or the appropriate host) once with the new flow, confirm the rebuild succeeds and the resulting system is functionally identical.
4. Commit:
   - Add `secrets/secrets.json.tpl`.
   - Update `flake.nix`, `justfile`, `modules/system/ssh/default.nix`.
   - Remove `secrets/secrets.json`, `.gitattributes` filters, `.git-crypt/`, `extras/helpers/setup-git-crypt.sh`.
   - Update docs.
5. After merge, on every other workstation: pull, `op signin` once, `just rebuild`.
6. Destroy the git-crypt key file (`~/.ssh/nixerator-git-crypt-key`) on every host once all hosts have been rebuilt successfully. The encrypted blobs in pre-cutover git history then become permanently unreadable, which is the desired end state.

Rollback: if step 3 fails, revert local changes; `secrets/secrets.json` is recoverable from `git stash` or `git checkout HEAD -- secrets/secrets.json`. Past step 4 commit (but before step 6 key-destroy), rollback is `git revert` plus restoring access via the still-extant git-crypt key.

### Verification

After implementation:
- `nix flake check --impure` (with `NIXERATOR_SECRETS` set) passes.
- `nix flake show` (without env var) succeeds with all hosts visible.
- `just rebuild qbert` on qbert produces a system identical in service config to the pre-cutover build (spot-check Claude Code MCP config, restic env, syncthing config, ssh client config).
- `grep -r 'filter=git-crypt' .gitattributes` returns nothing.
- `git-crypt status` reports the binary blobs in `secrets/*.png` and `secrets/yasd-export-*.json` as still encrypted (out of scope for this issue, addressed separately if at all).
- `cat secrets/secrets.json 2>&1` reports "No such file or directory".

## Open threads

- The remote-rebuild path (`just remote-rebuild <host>` if it exists) needs explicit handling to ship the rendered file to the target. Confirm during implementation by reading the existing remote-rebuild recipes.
- `secrets/init.png`, `secrets/sg.png`, `secrets/yasd-export-2026-3-4-v3.json` remain git-crypted. The `secrets/**` filter is split into a narrower one targeting only these blobs, OR they get moved out of `secrets/` and the filter is removed entirely. Defer to implementation.
- Whether to keep `secrets/` as a directory name once it contains only the template (locators) and the leftover binary blobs. Renaming is cosmetic; out of scope.
