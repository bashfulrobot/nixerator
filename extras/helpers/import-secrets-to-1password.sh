#!/usr/bin/env bash
# One-shot import of secrets/secrets.json into 1Password.
# Requires: op signed in to the user's Personal vault.
# Usage:    extras/helpers/import-secrets-to-1password.sh [--dry-run]
#
# Item naming: each top-level key (or top-level + first nested key for grouped
# values) becomes one 1P item. Fields use kebab-case. All items land in the
# vault named by VAULT (default: Personal).
#
# SECURITY NOTE: secrets pass through the op CLI's argv, which means they are
# transiently visible in /proc/<pid>/cmdline to any other process running as
# the same UID. This is intentional for the one-shot migration flow but means
# you MUST NOT run this script while any AI agent (Claude Code, Cursor, etc.)
# is active in another terminal — that is exactly the leak vector this repo
# is trying to close. Sign out of those tools before running, then sign back
# in once `op item list --vault=Personal | grep ^Nixerator` confirms success.
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
    printf 'op item create --vault=%q --category=password --title=%q' \
      "$VAULT" "$title"
    for f in "${fields[@]}"; do printf ' %q' "$f"; done
    printf '\n'
  else
    op item create --vault="$VAULT" --category=password --title="$title" "${fields[@]}"
  fi
}

j() { jq -r "$1" "$src"; }

mk "Nixerator GitHub PAT"           "token=$(j '.github.accessToken')"
mk "Nixerator Kong Konnect"         "pat=$(j '.kong.kongKonnectPAT')"
mk "Nixerator Context7"             "api-key=$(j '.context7.apiKey')"
mk "Nixerator Zai"                  "api-key=$(j '.zai.apiKey')"
mk "Nixerator Clay"                 "pin=$(j '.clay.pin')"
mk "Nixerator Claudito" \
    "username=$(j '.claudito.username')" \
    "password=$(j '.claudito.password')"
mk "Nixerator Syncthing GUI" \
    "user=$(j '.syncthing.gui.user')" \
    "password=$(j '.syncthing.gui.password')"
mk "Nixerator Host qbert" \
    "tailscale-ip=$(j '.qbert.tailscale_ip')" \
    "syncthing-id=$(j '.qbert.syncthing_id')" \
    "lan-ip=192.168.169.2"
mk "Nixerator Host donkey-kong" \
    "tailscale-ip=$(j '."donkey-kong".tailscale_ip')" \
    "syncthing-id=$(j '."donkey-kong".syncthing_id')" \
    "lan-ip=192.168.169.3"
mk "Nixerator Host srv" \
    "tailscale-ip=$(j '.srv.tailscale_ip')" \
    "lan-ip=192.168.168.1"
mk "Nixerator restic srv" \
    "repository=$(j '.restic.srv.restic_repository')" \
    "password=$(j '.restic.srv.restic_password')" \
    "b2-account-id=$(j '.restic.srv.b2_account_id')" \
    "b2-account-key=$(j '.restic.srv.b2_account_key')" \
    "region=$(j '.restic.srv.region')"
mk "Nixerator restic workstation" \
    "repository=$(j '.restic.workstation.restic_repository')" \
    "password=$(j '.restic.workstation.restic_password')" \
    "b2-account-id=$(j '.restic.workstation.b2_account_id')" \
    "b2-account-key=$(j '.restic.workstation.b2_account_key')" \
    "region=$(j '.restic.workstation.region')"
mk "Nixerator plakar qbert" \
    "repository=$(j '.plakar.qbert.repository')" \
    "passphrase=$(j '.plakar.qbert.passphrase')" \
    "b2-account-id=$(j '.plakar.qbert.b2_account_id')" \
    "b2-account-key=$(j '.plakar.qbert.b2_account_key')"
mk "Nixerator Gemini"               "api-key=$(j '.gemini.apiKey')"
mk "Nixerator Snyk"                 "token=$(j '.snyk.token')"
mk "Nixerator Todoist"              "token=$(j '.todoist_token')"
mk "Nixerator Tailscale caddy auth" "key=$(j '.tailscale.caddyAuthKey')"
mk "Nixerator SSH camino"           "hostname=64.225.50.102" "user=root"
mk "Nixerator SSH budgie"           "hostname=ubuntubudgie.org"
mk "Nixerator SSH feral" \
    "hostname=prometheus.feralhosting.com" \
    "user=msgedme"

echo "Done. Verify with: op item list --vault=$VAULT --categories=password | grep ^Nixerator"
