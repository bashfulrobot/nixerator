#!/usr/bin/env bash
# render-secrets — render Nix-eval secrets from 1Password to a file outside the repo.
#
# Usage:
#   render-secrets                       Render locally only.
#   render-secrets --check               Render to a temp file and diff against the
#                                        live file. Exit 1 if drift detected.
#   render-secrets --push HOST [HOST...] Render locally, then scp to each HOST at
#                                        the same path with 600 perms.
#
# Paths and 1Password references are baked in at Nix build time. Edit the module
# at modules/apps/cli/render-secrets/default.nix to change them.

set -euo pipefail

DEST="@DEST@"
TPL="@TPL@"

usage() {
    cat >&2 <<EOF
Usage: render-secrets [--check] [--push HOST [HOST...]]
  Renders 1Password-templated secrets to: ${DEST}
  Template:                                ${TPL}

  --check          Render to a temp file and diff against the live file. No write.
  --push HOST...   After rendering, scp the rendered file to each HOST at the same
                   path with 600 perms. Hosts are resolved via SSH config.
EOF
    exit 2
}

CHECK=0
PUSH=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            CHECK=1
            shift
            ;;
        --push)
            shift
            [[ $# -gt 0 ]] || { echo "--push requires at least one HOST" >&2; usage; }
            while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                PUSH+=("$1")
                shift
            done
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown arg: $1" >&2
            usage
            ;;
    esac
done

if [[ ! -f "${TPL}" ]]; then
    echo "render-secrets: template not found at ${TPL}" >&2
    echo "  Did you run from a checkout that includes secrets.json.tpl?" >&2
    exit 1
fi

if ! command -v op >/dev/null 2>&1; then
    echo "render-secrets: 'op' (1Password CLI) not in PATH" >&2
    exit 1
fi

DEST_DIR="$(dirname "${DEST}")"

render_to() {
    local out="$1"
    op inject -i "${TPL}" -o "${out}"
    chmod 600 "${out}"
}

if [[ "${CHECK}" -eq 1 ]]; then
    if [[ ! -f "${DEST}" ]]; then
        echo "render-secrets --check: no live file at ${DEST}" >&2
        exit 1
    fi
    tmp="$(mktemp)"
    trap 'rm -f "${tmp}"' EXIT
    render_to "${tmp}"
    if diff -u "${DEST}" "${tmp}" >/dev/null; then
        echo "render-secrets: no drift"
        exit 0
    fi
    echo "render-secrets: DRIFT detected (live vs 1Password):" >&2
    diff -u "${DEST}" "${tmp}" >&2 || true
    exit 1
fi

mkdir -p "${DEST_DIR}"
chmod 700 "${DEST_DIR}"
render_to "${DEST}"
echo "render-secrets: wrote ${DEST}"

if [[ ${#PUSH[@]} -gt 0 ]]; then
    for host in "${PUSH[@]}"; do
        echo "render-secrets: pushing to ${host}..."
        # Create parent dir on remote, push file, restrict perms.
        # BatchMode=yes so a missing key / unknown host fails fast instead of prompting.
        ssh -o BatchMode=yes -o ConnectTimeout=5 "${host}" \
            "mkdir -p '${DEST_DIR}' && chmod 700 '${DEST_DIR}'"
        scp -q -o BatchMode=yes -o ConnectTimeout=5 "${DEST}" "${host}:${DEST}"
        ssh -o BatchMode=yes -o ConnectTimeout=5 "${host}" "chmod 600 '${DEST}'"
        echo "render-secrets: pushed to ${host}:${DEST}"
    done
fi
