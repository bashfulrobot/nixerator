#!/usr/bin/env bash
# One-shot: stub out the nixerator/cloudflare-ddns 1Password item so
# render-secrets has something to inject. Replace the dummy via the 1P
# UI (or `op item edit`) before relying on it.
#
#   Vault:    nixerator
#   Title:    cloudflare-ddns        (must match secrets.json.tpl exactly)
#   Category: API Credential         (default `credential` field)
#   Scope:    Zone / DNS / Edit on the target zones only
#
# Safe to delete this script and its `just op-create-cloudflare-ddns`
# recipe once the real token is in 1Password.
set -euo pipefail

if ! command -v op >/dev/null 2>&1; then
  echo "op (1Password CLI) not on PATH" >&2
  exit 1
fi

if op item get cloudflare-ddns --vault=nixerator >/dev/null 2>&1; then
  echo "nixerator/cloudflare-ddns already exists; leaving it alone."
  exit 0
fi

op item create \
  --vault=nixerator \
  --category="API Credential" \
  --title="cloudflare-ddns" \
  credential="DUMMY_REPLACE_ME"

echo
echo "Created. Edit the credential field in 1Password, then:"
echo "  just render-secrets"
echo "  just push-secrets srv   # if rendering from a desktop"
