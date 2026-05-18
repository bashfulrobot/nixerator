# 1Password secrets — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace git-crypt-encrypted `secrets/secrets.json` with a 1Password-backed flow that renders secrets to a tmpfs file at rebuild time, keeping the existing inline `secrets.foo.bar` Nix pattern intact.

**Architecture:** Commit a `secrets/secrets.json.tpl` containing `op://Personal/<item>/<field>` locators. Wrap all `nixos-rebuild` invocations in a `just` recipe that runs `op inject` into `/run/user/$UID/nixerator-XXXXXX.json` (mode 600), passes the path to Nix via `NIXERATOR_SECRETS`, then `shred`s the file on exit. `flake.nix` reads from that env var instead of from the repo path.

**Tech Stack:** Nix flakes, `just`, `op` (1Password CLI v2.34.0), `mktemp`, `shred`.

**Design doc:** `docs/plans/2026-05-16-1password-secrets-design.md`.

---

## Hard prerequisites

User-action gates that an executing agent CANNOT satisfy alone. Each is marked **USER-GATE** in the task list. DM the user via the `slack-post` skill when reaching one.

1. **USER-GATE A — Populate 1Password.** Every `op://` URI in the template must resolve in the user's `Personal` vault before any `op inject` can succeed. Task 1 produces a helper script the user runs once to bulk-create the items.
2. **USER-GATE B — `op signin`.** Required for any local `op inject` test the agent wants to run. Touch ID per session.
3. **USER-GATE C — Sudo + real `nixos-rebuild`.** Final end-to-end verification needs the user at the keyboard to enter their sudo password.

The plan does as much as possible BEFORE Gate A so the user receives a single DM with a populated helper script ready to run.

---

## File structure

| Path | Action | Responsibility |
|---|---|---|
| `secrets/secrets.json.tpl` | **create** | JSON skeleton mirroring the current `secrets.json`, with leaf values as `op://Personal/…` locator strings. Source of truth for the template shape. |
| `extras/helpers/import-secrets-to-1password.sh` | **create** | One-shot reader of `secrets/secrets.json` that emits `op item create` commands to bulk-populate the user's `Personal` vault. Deleted after migration. |
| `flake.nix` | **modify** lines 133-135 | Switch from `readFile ./secrets/secrets.json` to `readFile (getEnv "NIXERATOR_SECRETS")`. |
| `modules/apps/cli/syncthing/default.nix` | **modify** | Add `secrets ? …` guards around peer-discovery and GUI-credentials blocks so `{}` fallback eval works. |
| `hosts/qbert/modules.nix` | **modify** lines 13-17 | Wrap restic block in `lib.mkIf (secrets ? restic …)`. |
| `hosts/donkeykong/modules.nix` | **modify** lines 26-30 | Wrap restic block in `lib.mkIf`. |
| `hosts/srv/modules.nix` | **modify** lines 141-144 | Wrap restic block in `lib.mkIf`. |
| `modules/system/ssh/default.nix` | **decrypt + refactor** | Remove from `.gitattributes` filter. Replace literal hostnames/users with `secrets.ssh.hosts.<name>.*` reads. |
| `justfile` | **modify** | Add `_render-secrets` private recipe. Wrap `rebuild`, `upgrade`, `quiet-rebuild`, `quiet-upgrade` to render before sudo. Update `remote-rebuild`/`remote-upgrade` to scp the rendered file to the target. |
| `.gitattributes` | **modify** | Delete the two `filter=git-crypt diff=git-crypt` lines. |
| `.git-crypt/` | **delete** | Whole directory (GPG users, key collaborators). |
| `secrets/secrets.json` | **delete** | After Gate A is confirmed populated and a render-test passes. |
| `secrets/init.png`, `secrets/sg.png`, `secrets/yasd-export-2026-3-4-v3.json` | **move** | Copy to `~/Documents/nixerator-secrets-orphans/`, then delete from repo. Add `secrets/*.png` and `secrets/yasd-*.json` to `.gitignore`. |
| `extras/helpers/setup-git-crypt.sh` | **delete** | Replaced by 1P bootstrap docs. |
| `extras/docs/secrets.md` | **rewrite** | New flow: template, render, signin, rotation via `op item edit`. |
| `extras/docs/bootstrap.txt` | **modify** step 4 | Drop git-crypt section, add `op signin` + `just rebuild` step. |
| `.gitignore` | **modify** | Add `secrets/secrets.json` (defense in depth) plus the moved-out binary blob patterns. |

---

## Task 1: Create 1P-import helper script

**Files:**
- Create: `extras/helpers/import-secrets-to-1password.sh`

- [ ] **Step 1: Write the helper**

```bash
#!/usr/bin/env bash
# One-shot import of secrets/secrets.json into 1Password.
# Requires: op signed in to the user's Personal vault.
# Usage:    extras/helpers/import-secrets-to-1password.sh [--dry-run]
#
# Item naming: each top-level key (or top-level + first nested key for grouped
# values) becomes one 1P item. Fields use kebab-case. All items land in the
# vault named by VAULT (default: Personal).
set -euo pipefail

VAULT="${VAULT:-Personal}"
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then DRY_RUN=1; fi

src="secrets/secrets.json"
if [[ ! -f "$src" ]]; then
  echo "error: $src not found (run from repo root, with git-crypt unlocked)" >&2
  exit 1
fi
if ! op whoami >/dev/null 2>&1; then
  echo "error: op not signed in. Run: eval \"\$(op signin)\"" >&2
  exit 1
fi

mk() {
  local title="$1"; shift
  local fields=("$@")
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'op item create --vault=%q --category=password --title=%q %s\n' \
      "$VAULT" "$title" "$(printf '%q ' "${fields[@]}")"
  else
    op item create --vault="$VAULT" --category=password --title="$title" "${fields[@]}"
  fi
}

j() { jq -r "$1" "$src"; }

mk "Nixerator GitHub PAT"          "token=$(j '.github.accessToken')"
mk "Nixerator Kong Konnect"        "pat=$(j '.kong.kongKonnectPAT')"
mk "Nixerator Context7"            "api-key=$(j '.context7.apiKey')"
mk "Nixerator Clay"                "pin=$(j '.clay.pin')"
mk "Nixerator Claudito"            "username=$(j '.claudito.username')" "password=$(j '.claudito.password')"
mk "Nixerator Syncthing GUI"       "user=$(j '.syncthing.gui.user')" "password=$(j '.syncthing.gui.password')"
mk "Nixerator Host qbert"          "tailscale-ip=$(j '.qbert.tailscale_ip')" "syncthing-id=$(j '.qbert.syncthing_id')" "lan-ip=192.168.169.2"
mk "Nixerator Host donkey-kong"    "tailscale-ip=$(j '.["donkey-kong"].tailscale_ip')" "syncthing-id=$(j '.["donkey-kong"].syncthing_id')" "lan-ip=192.168.169.3"
mk "Nixerator Host srv"            "tailscale-ip=$(j '.srv.tailscale_ip')" "lan-ip=192.168.168.1"
mk "Nixerator restic srv"          "repository=$(j '.restic.srv.restic_repository')" "password=$(j '.restic.srv.restic_password')" "b2-account-id=$(j '.restic.srv.b2_account_id')" "b2-account-key=$(j '.restic.srv.b2_account_key')" "region=$(j '.restic.srv.region')"
mk "Nixerator restic workstation"  "repository=$(j '.restic.workstation.restic_repository')" "password=$(j '.restic.workstation.restic_password')" "b2-account-id=$(j '.restic.workstation.b2_account_id')" "b2-account-key=$(j '.restic.workstation.b2_account_key')" "region=$(j '.restic.workstation.region')"
mk "Nixerator plakar qbert"        "repository=$(j '.plakar.qbert.repository')" "passphrase=$(j '.plakar.qbert.passphrase')" "b2-account-id=$(j '.plakar.qbert.b2_account_id')" "b2-account-key=$(j '.plakar.qbert.b2_account_key')"
mk "Nixerator Gemini"              "api-key=$(j '.gemini.apiKey')"
mk "Nixerator Snyk"                "token=$(j '.snyk.token')"
mk "Nixerator Todoist"             "token=$(j '.todoist_token')"
mk "Nixerator Tailscale caddy auth" "key=$(j '.tailscale.caddyAuthKey')"
mk "Nixerator Zai"                 "api-key=$(j '.zai.apiKey')"
mk "Nixerator SSH camino"          "hostname=64.225.50.102" "user=root"
mk "Nixerator SSH budgie"          "hostname=ubuntubudgie.org"
mk "Nixerator SSH feral"           "hostname=prometheus.feralhosting.com" "user=msgedme"

echo "Done. Verify with: op item list --vault=$VAULT --tags= | grep ^Nixerator"
```

- [ ] **Step 2: Make executable + dry-run test**

```bash
chmod +x extras/helpers/import-secrets-to-1password.sh
extras/helpers/import-secrets-to-1password.sh --dry-run | head -5
```

Expected: prints `op item create --vault=Personal --category=password --title="Nixerator GitHub PAT" token=...` etc.

- [ ] **Step 3: Commit**

```bash
git add extras/helpers/import-secrets-to-1password.sh
git commit -m "feat(secrets): add 1Password import helper (#61)"
```

---

## Task 2: Create the secrets template

**Files:**
- Create: `secrets/secrets.json.tpl`

- [ ] **Step 1: Write the template**

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
  "zai": {
    "apiKey": "op://Personal/Nixerator Zai/api-key"
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
  "srv": {
    "tailscale_ip": "op://Personal/Nixerator Host srv/tailscale-ip"
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
  "plakar": {
    "qbert": {
      "repository": "op://Personal/Nixerator plakar qbert/repository",
      "passphrase": "op://Personal/Nixerator plakar qbert/passphrase",
      "b2_account_id": "op://Personal/Nixerator plakar qbert/b2-account-id",
      "b2_account_key": "op://Personal/Nixerator plakar qbert/b2-account-key"
    }
  },
  "gemini": {
    "apiKey": "op://Personal/Nixerator Gemini/api-key"
  },
  "snyk": {
    "token": "op://Personal/Nixerator Snyk/token"
  },
  "todoist_token": "op://Personal/Nixerator Todoist/token",
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

- [ ] **Step 2: Verify JSON is well-formed and shape matches current secrets**

```bash
jq -e . secrets/secrets.json.tpl >/dev/null && echo "template parses"
diff <(jq -S 'paths(type=="string")|join(".")' secrets/secrets.json | sort) \
     <(jq -S 'paths(type=="string")|join(".")' secrets/secrets.json.tpl | sort) \
     | grep -E '^[<>]' || echo "schema OK"
```

Expected: `template parses` and either `schema OK` or only the `ssh.hosts.*` lines added (new in template).

- [ ] **Step 3: Commit**

```bash
git add secrets/secrets.json.tpl
git commit -m "feat(secrets): add 1Password template (#61)"
```

---

## Task 3: Modify `flake.nix` to source from env var

**Files:**
- Modify: `flake.nix` lines 133-135

- [ ] **Step 1: Replace the secrets-loading block**

Replace:

```nix
      # Load secrets from encrypted JSON file
      secretsFile = "${self}/secrets/secrets.json";
      secrets = builtins.fromJSON (builtins.readFile secretsFile);
```

With:

```nix
      # Load secrets from a path supplied via NIXERATOR_SECRETS (rendered by
      # `just _render-secrets` from secrets/secrets.json.tpl via `op inject`).
      # When the env var is unset, eval falls back to an empty attrset so
      # `nix flake show` / `nix flake check` work without an op session.
      # Modules that consume secrets unconditionally are guarded with
      # `secrets ? foo` to keep eval clean.
      secretsPath = builtins.getEnv "NIXERATOR_SECRETS";
      secrets =
        if secretsPath != ""
        then builtins.fromJSON (builtins.readFile secretsPath)
        else { };
```

- [ ] **Step 2: Verify the file still parses**

```bash
nix-instantiate --parse flake.nix >/dev/null && echo "flake.nix parses"
```

Expected: `flake.nix parses`.

- [ ] **Step 3: DO NOT commit yet** — Task 4-6 add the guards that this change depends on.

---

## Task 4: Guard unconditional `secrets` reads in `syncthing/default.nix`

**Files:**
- Modify: `modules/apps/cli/syncthing/default.nix`

- [ ] **Step 1: Read the current file to confirm line numbers**

```bash
grep -n 'secrets\.' modules/apps/cli/syncthing/default.nix
```

Expected hits at lines 70, 81, 82, 178, 179.

- [ ] **Step 2: Wrap the GUI credentials block**

Find the block around line 70 that contains `inherit (secrets.syncthing.gui) user password;`. Wrap the enclosing attribute (which feeds the `services.syncthing.settings.gui` or similar) so the whole GUI configuration is conditional. Use `lib.mkIf (secrets ? syncthing && secrets.syncthing ? gui)` around the option binding. If the surrounding structure prevents `mkIf`, fall back to per-leaf `or` defaults:

```nix
inherit (secrets.syncthing.gui or { user = null; password = null; }) user password;
```

(Pick whichever fits the existing structure; if unsure, prefer the `or { … = null; }` form because it's a one-line change.)

- [ ] **Step 3: Wrap the peer-discovery entries**

For each `addresses = [ "tcp://${secrets.qbert.tailscale_ip}:22000" ];` and `id = secrets.qbert.syncthing_id;`, replace with `or`-guarded reads:

```nix
addresses = [ "tcp://${secrets.qbert.tailscale_ip or "0.0.0.0"}:22000" ];
id = secrets.qbert.syncthing_id or "";
```

Do the same for the `donkey-kong` block (lines 178-179).

Rationale: with `{}` fallback, peer config gets bogus-but-valid strings. The system would be misconfigured but eval succeeds. Real rebuilds via `just rebuild` get real values.

- [ ] **Step 4: Verify**

```bash
NIXERATOR_SECRETS="" nix eval --impure --expr 'builtins.tryEval (import ./flake.nix).outputs' 2>&1 | head -3
```

Best-effort eval check; full `nix flake check` runs in Task 6.

---

## Task 5: Guard restic blocks in host modules

**Files:**
- Modify: `hosts/qbert/modules.nix` lines 13-17
- Modify: `hosts/donkeykong/modules.nix` lines 26-30
- Modify: `hosts/srv/modules.nix` lines 141-144

- [ ] **Step 1: Read each block to capture the surrounding context**

```bash
sed -n '10,25p' hosts/qbert/modules.nix
sed -n '20,35p' hosts/donkeykong/modules.nix
sed -n '135,155p' hosts/srv/modules.nix
```

- [ ] **Step 2: Replace each restic reference with `or` defaults**

For each of the three files, replace:

```nix
repository      = secrets.restic.workstation.restic_repository;
password        = secrets.restic.workstation.restic_password;
awsAccessKeyId  = secrets.restic.workstation.b2_account_id;
awsSecretAccessKey = secrets.restic.workstation.b2_account_key;
awsRegion       = secrets.restic.workstation.region;
```

With:

```nix
repository      = secrets.restic.workstation.restic_repository or "";
password        = secrets.restic.workstation.restic_password or "";
awsAccessKeyId  = secrets.restic.workstation.b2_account_id or "";
awsSecretAccessKey = secrets.restic.workstation.b2_account_key or "";
awsRegion       = secrets.restic.workstation.region or "us-west-000";
```

(In `hosts/srv/modules.nix` the path is `.srv` instead of `.workstation`.)

Empty-string defaults are fine for `--impure --flake check`. They produce a syntactically valid systemd config that's functionally broken — exactly what's wanted when there's no secrets context.

- [ ] **Step 3: Verify all three files parse**

```bash
for f in hosts/qbert/modules.nix hosts/donkeykong/modules.nix hosts/srv/modules.nix; do
  nix-instantiate --parse "$f" >/dev/null && echo "$f OK"
done
```

Expected: three `OK` lines.

---

## Task 6: Verify `nix flake check` works without `NIXERATOR_SECRETS`

**Files:** none

- [ ] **Step 1: Run flake check with unset env var**

```bash
unset NIXERATOR_SECRETS
nix flake check --impure --no-build 2>&1 | tail -20
```

Expected: completes without "attribute … is missing" errors. Warnings about empty strings or unused names are acceptable.

- [ ] **Step 2: If errors surface, add additional `or` guards inline**

Each error names a path like `error: attribute 'foo' missing`. Find every reader of that path and add `or ""` / `or null` defaults. Re-run step 1 until clean.

- [ ] **Step 3: Commit the flake + guards**

```bash
git add flake.nix modules/apps/cli/syncthing/default.nix \
        hosts/qbert/modules.nix hosts/donkeykong/modules.nix hosts/srv/modules.nix
git commit -m "feat(secrets): source secrets from NIXERATOR_SECRETS env var (#61)"
```

---

## Task 7: Refactor `modules/system/ssh/default.nix`

**Files:**
- Modify: `modules/system/ssh/default.nix`

- [ ] **Step 1: Confirm the file is currently plaintext in the worktree**

```bash
head -1 modules/system/ssh/default.nix
```

Expected: starts with `{` (the worktree was unlocked at setup; if this is the git-crypt header, run `git-crypt unlock ~/.ssh/nixerator-git-crypt-key`).

- [ ] **Step 2: Add `secrets` to the module arglist**

Edit the file header:

```nix
{
  globals,
  lib,
  config,
  secrets,
  ...
}:
```

- [ ] **Step 3: Replace each literal with a `secrets.ssh.hosts.*` read**

Inside the `matchBlocks = { … }` attrset:

```nix
"camino" = {
  hostname = secrets.ssh.hosts.camino.hostname or "camino.invalid";
  user     = secrets.ssh.hosts.camino.user or "root";
};

"budgie" = {
  hostname = secrets.ssh.hosts.budgie.hostname or "budgie.invalid";
  user     = globals.user.name;
};

"feral" = {
  hostname = secrets.ssh.hosts.feral.hostname or "feral.invalid";
  user     = secrets.ssh.hosts.feral.user or "nobody";
};

"qbert" = {
  hostname = secrets.ssh.hosts.qbert_lan or "0.0.0.0";
  user = globals.user.name;
  identityFile = "~/.ssh/id_ed25519";
  forwardAgent = true;
};

"srv" = {
  hostname = secrets.ssh.hosts.srv_lan or "0.0.0.0";
  user = globals.user.name;
  identityFile = "~/.ssh/id_ed25519";
  forwardAgent = true;
};

"dk" = {
  hostname = secrets.ssh.hosts.dk_lan or "0.0.0.0";
  user = globals.user.name;
  identityFile = "~/.ssh/id_ed25519";
  forwardAgent = true;
};

# TF/KVM block: key is the srv LAN IP literal. With dynamic secret, key the
# block by a stable alias and supply the IP via `hostname`.
"srv-tf" = {
  hostname = secrets.ssh.hosts.srv_lan or "0.0.0.0";
  user = globals.user.name;
  port = 22;
  checkHostIP = false;
  extraOptions = {
    StrictHostKeyChecking = "no";
    UserKnownHostsFile = "/dev/null";
  };
};
```

The `github.com`, `bitbucket.org`, `git.srvrs.co` entries stay literal (public hosts; not topology-sensitive).

- [ ] **Step 4: Remove the file from the git-crypt filter**

Edit `.gitattributes`:

Before:
```
secrets/** filter=git-crypt diff=git-crypt
modules/system/ssh/default.nix filter=git-crypt diff=git-crypt
```

After (delete the second line):
```
secrets/** filter=git-crypt diff=git-crypt
```

(The `secrets/**` line stays for now — Task 14 narrows or removes it.)

- [ ] **Step 5: Verify parse**

```bash
nix-instantiate --parse modules/system/ssh/default.nix >/dev/null && echo "ssh module OK"
```

- [ ] **Step 6: Commit**

```bash
git add modules/system/ssh/default.nix .gitattributes
git commit -m "refactor(ssh): read host topology from secrets, drop git-crypt (#61)"
```

---

## Task 8: Add justfile `_render-secrets` helper

**Files:**
- Modify: `justfile` (add new private recipe)

- [ ] **Step 1: Add the recipe near the other private helpers (after `pre-rebuild` / `post-rebuild`)**

Insert this block in the justfile, placed alphabetically near other `[private]` helpers:

```just
# Render secrets template via `op inject` into a tmpfs file.
# Prints the path on stdout for the caller to capture and trap-cleanup.
# Auto-prompts `op signin` if not already authenticated.
[private]
_render-secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! op whoami >/dev/null 2>&1; then
        eval "$(op signin)"
    fi
    runtime_dir="/run/user/$(id -u)"
    if [[ ! -d "$runtime_dir" ]]; then
        runtime_dir="${TMPDIR:-/tmp}"
    fi
    rendered=$(mktemp -p "$runtime_dir" nixerator-XXXXXX.json)
    chmod 600 "$rendered"
    op inject -i secrets/secrets.json.tpl -o "$rendered"
    echo "$rendered"
```

- [ ] **Step 2: Verify the recipe is recognised**

```bash
just --list 2>&1 | grep -c '_render-secrets' || true
```

(Private recipes are hidden by default; the count may be 0. Run `just --unsorted --list-detail private | grep _render-secrets` to confirm.)

- [ ] **Step 3: Commit**

```bash
git add justfile
git commit -m "feat(justfile): add _render-secrets helper (#61)"
```

---

## Task 9: Wrap the four rebuild recipes with env-var passthrough

**Files:**
- Modify: `justfile` recipes `rebuild` (line 25), `upgrade` (line 66), `quiet-rebuild` (line 343), `quiet-upgrade` (line 378)

Each existing recipe contains a line like:

```bash
sudo nixos-rebuild switch --impure --flake {{host_flake}} …
```

The wrap pattern: render before `pre-rebuild`, trap shred on exit, pass env var through sudo.

- [ ] **Step 1: Modify `rebuild` (interactive, line 25-55)**

Insert after `set -uo pipefail`:

```bash
    rendered=$(just _render-secrets)
    trap 'shred -u "$rendered" 2>/dev/null || rm -f "$rendered"' EXIT
    export NIXERATOR_SECRETS="$rendered"
```

Change the `sudo nixos-rebuild` line so `sudo` preserves the env var:

```bash
    gum spin --spinner dot --title "Rebuilding NixOS configuration..." \
        -- bash -c 'sudo --preserve-env=NIXERATOR_SECRETS nixos-rebuild switch --impure --flake {{host_flake}} &> "'"$log"'"' || rc=$?
```

- [ ] **Step 2: Apply the same pattern to `upgrade` (line 66-110ish)**

Same `rendered=$(just _render-secrets)` + trap + export + `--preserve-env=NIXERATOR_SECRETS` on the sudo line.

- [ ] **Step 3: Apply to `quiet-rebuild` (line 343-376)**

Same pattern. The sudo call there is:

```bash
    sudo --preserve-env=NIXERATOR_SECRETS nixos-rebuild switch --impure --flake {{host_flake}} &> {{rebuild_log}} || rc=$?
```

- [ ] **Step 4: Apply to `quiet-upgrade` (line 378-end)**

Same pattern.

- [ ] **Step 5: Sanity-check the diff**

```bash
git diff justfile | grep -E '^[+-]' | head -40
```

Confirm four occurrences of `rendered=$(just _render-secrets)` and four of `--preserve-env=NIXERATOR_SECRETS`.

- [ ] **Step 6: Commit**

```bash
git add justfile
git commit -m "feat(justfile): render secrets before every rebuild/upgrade (#61)"
```

---

## Task 10: Update `remote-rebuild` and `remote-upgrade` to ship rendered secrets

**Files:**
- Modify: `justfile` `remote-rebuild` (around line 414) and `remote-upgrade` (just below)

The remote target runs its own `just qr` over SSH. Two compatible approaches:

(a) Render locally, scp the file to the target's `/run/user/$UID/`, run `just qr` with the env var pointing at the scp'd path.
(b) Have the target render via its own `op` session (requires `op` on the target + signed in).

Approach (a) avoids needing `op signin` on the target. Use it.

- [ ] **Step 1: Replace the `remote-rebuild` body**

Replace:

```bash
    ssh -A -o BatchMode=yes -o ConnectTimeout=5 {{host}} \
        "cd {{repo_path}} && git pull --ff-only && just qr" || rc=$?
```

With:

```bash
    rendered=$(just _render-secrets)
    trap 'shred -u "$rendered" 2>/dev/null || rm -f "$rendered"' EXIT
    remote_path="/run/user/$(ssh -o BatchMode=yes {{host}} id -u)/nixerator-remote-$$.json"
    scp -q -o BatchMode=yes "$rendered" "{{host}}:$remote_path"
    ssh -A -o BatchMode=yes -o ConnectTimeout=5 {{host}} \
        "cd {{repo_path}} && git pull --ff-only && NIXERATOR_SECRETS=$remote_path just qr; rm -f $remote_path" || rc=$?
```

- [ ] **Step 2: Same change to `remote-upgrade`** (the equivalent block calling `just qu`).

- [ ] **Step 3: Commit**

```bash
git add justfile
git commit -m "feat(justfile): ship rendered secrets to remote rebuild targets (#61)"
```

---

## Task 11: USER-GATE A — DM the user to populate 1Password

**Files:** none (action, not edit)

- [ ] **Step 1: Compose Slack DM via the slack-post skill**

Body:

> *Issue #61 — ready for your 1P populate step*
>
> The implementation is ready up to the point where it needs your `Personal` vault populated. Two commands:
>
> 1. `eval (op signin)` (Touch ID)
> 2. `extras/helpers/import-secrets-to-1password.sh --dry-run | head -20` (sanity check — confirms what items will be created)
> 3. `extras/helpers/import-secrets-to-1password.sh` (creates ~20 items in your Personal vault, prefixed `Nixerator …`)
>
> Reply when populated and I'll run the render test and resume.

Run:

```bash
bash ~/.claude/skills/slack-post/scripts/slack-post.sh --self --send --stdin <<'EOF'
… body above …
EOF
```

- [ ] **Step 2: Wait for user confirmation in the conversation**

The user will reply when 1P is populated. Do not advance.

---

## Task 12: Render-test against populated 1P

**Files:** none (verification)

- [ ] **Step 1: Run the render**

```bash
just _render-secrets > /tmp/render-test-path
rendered=$(cat /tmp/render-test-path)
echo "rendered to: $rendered"
jq -e . "$rendered" >/dev/null && echo "valid JSON"
```

Expected: `valid JSON`.

- [ ] **Step 2: Shape diff against the original secrets.json**

```bash
diff <(jq -S 'paths(type=="string")|join(".")' secrets/secrets.json | sort) \
     <(jq -S 'paths(type=="string")|join(".")' "$rendered" | sort) \
     | grep -E '^[<>]' || echo "schema parity OK"
```

Expected: lines added under `ssh.hosts.*` (new in template) but no removals or unexpected differences.

- [ ] **Step 3: Compare every value matches**

```bash
diff <(jq -S . secrets/secrets.json) <(jq -S 'del(.ssh)' "$rendered") | head -30
```

Expected: no diffs (or only differences explainable by intentional schema changes).

- [ ] **Step 4: Shred the test render**

```bash
shred -u "$rendered" && rm /tmp/render-test-path
```

If any diff is unexpected, fix the template or the 1P items, then re-run Task 12 before advancing.

---

## Task 13: USER-GATE C — DM the user to run `just rebuild` end-to-end

**Files:** none (action)

- [ ] **Step 1: Compose Slack DM**

Body:

> *Issue #61 — end-to-end rebuild test*
>
> Render test passes. Please run `just rebuild` on this host (qbert/donkeykong/whichever) and confirm:
> 1. Touch ID prompt fires (for `op signin`).
> 2. Sudo prompt fires.
> 3. Rebuild completes without errors.
> 4. `just rebuild` exits 0 and the host's services are healthy.
>
> If anything fails, send me the tail of `/tmp/nixerator-rebuild.log` (for `just qr`) or the error from the interactive output. Reply "rebuilt OK" when done.

Send via slack-post.

- [ ] **Step 2: Wait for confirmation**

If the user reports failure, diagnose from the log and iterate.

---

## Task 14: Move binary blobs out of `secrets/`, remove from repo

**Files:**
- Move: `secrets/init.png`, `secrets/sg.png`, `secrets/yasd-export-2026-3-4-v3.json` → `~/Documents/nixerator-personal-orphans/`
- Modify: `.gitignore`

- [ ] **Step 1: Copy the blobs to a safe location outside the repo**

```bash
mkdir -p ~/Documents/nixerator-personal-orphans
cp secrets/init.png secrets/sg.png secrets/yasd-export-2026-3-4-v3.json \
   ~/Documents/nixerator-personal-orphans/
ls -la ~/Documents/nixerator-personal-orphans/
```

- [ ] **Step 2: Delete from the repo**

```bash
git rm secrets/init.png secrets/sg.png secrets/yasd-export-2026-3-4-v3.json
```

- [ ] **Step 3: Add patterns to `.gitignore`**

Append to `.gitignore`:

```
# Personal binary artifacts (kept outside the repo since git-crypt removal)
secrets/*.png
secrets/yasd-*.json
secrets/secrets.json
```

The last line is defense in depth — keeps a stray `op inject -o secrets/secrets.json` from accidentally landing in the repo.

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore(secrets): move binary blobs outside repo, gitignore (#61)"
```

---

## Task 15: Remove the last git-crypt filter

**Files:**
- Modify: `.gitattributes`

- [ ] **Step 1: Drop the `secrets/**` line**

After Task 14 the `secrets/` directory contains only `secrets.json.tpl` (plaintext locator file, no encryption needed). Remove the remaining filter.

Edit `.gitattributes` and delete:

```
secrets/** filter=git-crypt diff=git-crypt
```

The file should end up with no git-crypt filter lines at all.

- [ ] **Step 2: Verify the template still tracks as plaintext**

```bash
git check-attr filter secrets/secrets.json.tpl
```

Expected: `secrets/secrets.json.tpl: filter: unspecified`.

- [ ] **Step 3: Commit**

```bash
git add .gitattributes
git commit -m "chore(secrets): drop git-crypt filter (#61)"
```

---

## Task 16: Delete `.git-crypt/` and `secrets/secrets.json`

**Files:**
- Delete: `.git-crypt/` (whole directory)
- Delete: `secrets/secrets.json`
- Delete: `extras/helpers/setup-git-crypt.sh`
- Delete: `extras/helpers/import-secrets-to-1password.sh` (it has fulfilled its purpose)

- [ ] **Step 1: Verify the user has confirmed 1P populated and rebuild succeeded** (Tasks 11-13).

Skip if either user-gate is unresolved.

- [ ] **Step 2: Remove the files**

```bash
git rm -r .git-crypt/
git rm secrets/secrets.json
git rm extras/helpers/setup-git-crypt.sh
git rm extras/helpers/import-secrets-to-1password.sh
```

- [ ] **Step 3: Verify `secrets/` directory now contains only the template**

```bash
ls secrets/
```

Expected: `secrets.json.tpl` only.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(secrets): remove git-crypt config and plaintext secrets.json (#61)"
```

---

## Task 17: Rewrite `extras/docs/secrets.md`

**Files:**
- Modify: `extras/docs/secrets.md` (full rewrite)

- [ ] **Step 1: Replace the file contents**

New body:

````markdown
# Secrets management

Secrets are stored in the user's 1Password `Personal` vault. The repo commits a template (`secrets/secrets.json.tpl`) that references them by `op://…` locator. At rebuild time, `just` renders the template into a short-lived tmpfs file and passes the path to Nix via the `NIXERATOR_SECRETS` env var.

## How it works

1. `secrets/secrets.json.tpl` — committed JSON, every leaf value is `op://Personal/<item>/<field>`. No credentials in the repo.
2. `just rebuild` (and `upgrade`, `quiet-rebuild`, `quiet-upgrade`) runs `op inject` into `/run/user/$UID/nixerator-XXXXXX.json` (mode 600), exports `NIXERATOR_SECRETS=$path`, runs `sudo --preserve-env=NIXERATOR_SECRETS nixos-rebuild switch --impure`, and `shred -u`s the file on exit.
3. `flake.nix` reads `NIXERATOR_SECRETS`; empty env var falls back to an empty attrset so `nix flake show` / `nix flake check` work without an `op` session.

## Daily flow

```bash
just rebuild        # touch ID for op signin, sudo prompt, rebuild, shred
```

No other ceremony. If `op` is already signed in, the Touch ID prompt is skipped.

## Rotation

```bash
op item edit "Nixerator Kong Konnect" pat=NEW_VALUE
just rebuild
```

The template is unchanged — only the 1P item gets edited.

## Adding a new secret

1. Create the 1P item: `op item create --vault=Personal --category=password --title="Nixerator Foo" key=value`.
2. Add a leaf to `secrets/secrets.json.tpl`: `"foo": { "key": "op://Personal/Nixerator Foo/key" }`.
3. Reference it in a Nix module: `secrets.foo.key`. If the consumer is mandatory, add `or ""` / `lib.mkIf (secrets ? foo)` so `nix flake check` (no env var) still passes.
4. Commit and rebuild.

## Initial setup on a new machine

See `extras/docs/bootstrap.txt` step 4.

Short form: install `op`, `op signin`, `just rebuild`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `op: command not found` during rebuild | `_1password-cli` not installed | `nix-shell -p _1password-cli` (temporary) or rebuild a host that includes it |
| `error: cannot read /tmp/…/nixerator-….json` | Render failed silently | Run `just _render-secrets` directly, inspect the `op inject` error |
| `op inject: validation failed: secret reference is invalid` | A `op://` URI doesn't match a 1P item | `op item list --vault=Personal --tags= \| grep Nixerator` to verify item names |
| `nix flake check` fails on `attribute … missing` | Consumer doesn't have an `or` guard | Add `or ""` / `or null` at the call site |

## AI-leak posture

Working tree contains only `op://` locators (not credentials). Plaintext exists in `/run/user/$UID/nixerator-XXXXXX.json` (mode 600, tmpfs, outside the repo) for the ~5 seconds of one rebuild, shredded on exit. `/nix/store` still bakes values into derived configs — accepted single-user tradeoff. See `docs/plans/2026-05-16-1password-secrets-design.md` for the threat-model table.
````

- [ ] **Step 2: Commit**

```bash
git add extras/docs/secrets.md
git commit -m "docs(secrets): rewrite for 1Password flow (#61)"
```

---

## Task 18: Update `extras/docs/bootstrap.txt`

**Files:**
- Modify: `extras/docs/bootstrap.txt` step 4 + step 9 + troubleshooting

- [ ] **Step 1: Replace step 4 ("Setup git-crypt")**

Old:

```
## Step 4: Setup git-crypt
scp "$SOURCE_SSH:~/.ssh/nixerator-git-crypt-key" ~/.ssh/
chmod 600 ~/.ssh/nixerator-git-crypt-key
./extras/helpers/setup-git-crypt.sh
```

New:

```
## Step 4: Install op CLI and sign in
nix-shell -p _1password-cli --run 'op signin'
# Follow the prompts: add your 1Password account, then biometric / master password.
# `op` is now available for the remainder of this shell.
```

- [ ] **Step 2: Replace the SSH-key-copy block in step 9 that mentions `nixerator-git-crypt-key`**

Drop the two lines:

```
sudo scp "$SOURCE_SSH:~/.ssh/nixerator-git-crypt-key" "$TARGET_HOME/.ssh/"
sudo chmod 600 "$TARGET_HOME/.ssh/nixerator-git-crypt-key"
```

- [ ] **Step 3: Replace step 12's "verify" line referencing `git-crypt status`**

Old:

```
cd "$REPO_PATH" && git-crypt status && git status
```

New:

```
cd "$REPO_PATH" && op whoami && git status
```

- [ ] **Step 4: Update step 12 rebuild line**

Old:

```
sudo nixos-rebuild switch --flake "$REPO_PATH#$TARGET_HOST"
```

New:

```
just rebuild     # renders secrets via op, then sudo nixos-rebuild
```

- [ ] **Step 5: Drop the "git-crypt fails" troubleshooting line**

Remove:

```
# git-crypt fails: verify key (ls -l ~/.ssh/nixerator-git-crypt-key), should be 600
```

Replace with:

```
# op signin fails: check `op account list`, re-run `op signin` and follow prompts
# render fails: run `just _render-secrets` directly; check item names with `op item list --vault=Personal`
```

- [ ] **Step 6: Commit**

```bash
git add extras/docs/bootstrap.txt
git commit -m "docs(bootstrap): replace git-crypt step with 1P signin (#61)"
```

---

## Task 19: Final `nix flake check` with rendered secrets

**Files:** none (verification)

- [ ] **Step 1: Render and run flake check**

```bash
rendered=$(just _render-secrets)
trap 'shred -u "$rendered" 2>/dev/null || rm -f "$rendered"' EXIT
NIXERATOR_SECRETS="$rendered" nix flake check --impure --no-build 2>&1 | tail -10
```

Expected: completes cleanly. Any "attribute … missing" errors point to a callsite that still needs an `or` guard — fix and re-run.

- [ ] **Step 2: One more eval check without env var (regression catch)**

```bash
unset NIXERATOR_SECRETS
nix flake check --impure --no-build 2>&1 | tail -10
```

Expected: same clean result. If this passes but the rendered run failed, the issue is in the template or 1P items, not the Nix code.

---

## Task 20: Push branch, open PR

**Files:** none (PR creation)

- [ ] **Step 1: Push**

```bash
git push -u origin feat/61-assess-using-1password-instead-of-git-cryp
```

- [ ] **Step 2: Open PR via `github-issue` skill push step**

The `github-issue` skill's `push` state handles label propagation and PR creation. Trigger by transitioning, then running:

```bash
github-issue push 61
```

- [ ] **Step 3: Confirm the PR body uses `Closes #61`** (default; multi-phase issues use `Refs #61` instead — this is atomic, leave as `Closes`).

- [ ] **Step 4: Confirm the PR is open and CI is queued**

```bash
gh pr view --json url,state,statusCheckRollup --jq '{url,state,checks: [.statusCheckRollup[].name]}'
```

---

## Self-review

- **Spec coverage:** Each section of the design doc has a task. Template → Task 2. Flake change → Task 3. Guards → Tasks 4-6. SSH refactor → Task 7. Justfile → Tasks 8-10. Migration manual steps → Tasks 11, 13. Cleanup → Tasks 14-16. Docs → Tasks 17-18. Verification → Tasks 6, 12, 19. PR → Task 20.
- **Placeholder scan:** No "TBD"/"TODO"/"fill in" markers. Every code block contains the actual content.
- **Type consistency:** `secrets.ssh.hosts.<name>.*` is used in both Task 2 (template) and Task 7 (SSH module) with matching field names (`hostname`, `user`, `qbert_lan`, `srv_lan`, `dk_lan`). `secrets.restic.workstation.*` and `.srv.*` paths in Task 5 match Task 2's schema. The `_render-secrets` recipe name is consistent across Tasks 8-10.
- **One known cross-task assumption:** Task 4-5 use `or ""` / `or "0.0.0.0"` defaults under the empty-attrset fallback. Task 6 verifies this works end-to-end. If a callsite isn't caught by Task 4/5 (e.g., a less-visible reader in a sub-module), Task 6 will surface it as a `nix flake check` error and the executor adds a guard inline.

## Execution

Subagent-driven per task is overkill for this size of plan; many tasks are mechanical edits with clear verification. Inline execution via `superpowers:executing-plans` is the right choice — checkpoint at the user-gate tasks (11, 13).
