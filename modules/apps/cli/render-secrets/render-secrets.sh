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
# DEST/TPL are baked at Nix build time. TPL is overridden to "${PWD}/secrets.json.tpl"
# when that exists, so editing the template from a git worktree works without
# rebuilding. Module: modules/apps/cli/render-secrets/default.nix.

set -euo pipefail

DEST="@DEST@"
TPL="@TPL@"

# Worktree override: prefer a co-located template in the caller's cwd. Lets
# `cd ~/git/.worktrees/issue-N && render-secrets` pick up that worktree's
# template instead of the baked main-clone path.
if [[ -f "${PWD}/secrets.json.tpl" ]]; then
    TPL="${PWD}/secrets.json.tpl"
fi

usage() {
    cat >&2 <<EOF
Usage: render-secrets [--check] [--push HOST [HOST...]]
  Renders 1Password-templated secrets to: ${DEST}
  Template:                                ${TPL}

  --check          Render to a temp file and diff against the live file. No write.
  --push HOST...   After rendering, scp the rendered file to each HOST at the same
                   path with 600 perms. Hosts are resolved via SSH config.

Notes:
  --push requires at least one non-flag HOST immediately after it.
  Atomic writes — partial failures never leave DEST or remote files truncated.
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
            # Must be followed by at least one non-flag arg, otherwise the user
            # wrote `--push --check` (or similar) and would silently no-op the
            # push if we accepted it.
            [[ $# -gt 0 && ! "$1" =~ ^- ]] || {
                echo "--push requires at least one HOST (got: '${1:-<end of args>}')" >&2
                usage
            }
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

# Render to a tmp file inside DEST_DIR (so the mv is atomic and on the same
# filesystem), chmod, then rename. A partial op-inject failure or SIGINT leaves
# the live DEST untouched.
render_to() {
    local out="$1"
    local tmp
    tmp="$(mktemp -p "$(dirname "${out}")" .render-secrets.XXXXXX)"
    # If op fails or we get interrupted between create and rename, clean up.
    trap 'rm -f "${tmp}"' RETURN
    op inject -i "${TPL}" -o "${tmp}"
    chmod 600 "${tmp}"
    mv -f "${tmp}" "${out}"
    trap - RETURN
}

if [[ "${CHECK}" -eq 1 ]]; then
    if [[ ! -f "${DEST}" ]]; then
        echo "render-secrets --check: no live file at ${DEST}" >&2
        exit 1
    fi
    # Tempfile lives inside DEST_DIR (0700) so secrets never sit in /tmp.
    mkdir -p "${DEST_DIR}"
    chmod 700 "${DEST_DIR}"
    tmp="$(mktemp -p "${DEST_DIR}" .render-secrets-check.XXXXXX)"
    trap 'rm -f "${tmp}"' EXIT
    op inject -i "${TPL}" -o "${tmp}"
    chmod 600 "${tmp}"
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
    # Track per-host outcome so a mid-list failure doesn't silently skip the
    # rest. We still exit non-zero at the end if any host failed.
    failed_hosts=()
    for host in "${PUSH[@]}"; do
        echo "render-secrets: pushing to ${host}..."
        rc=0
        # Stage to ${DEST}.tmp on the remote (same dir as DEST, same fs), then
        # atomically mv. Partial scp leaves DEST untouched.
        ssh -o BatchMode=yes -o ConnectTimeout=5 "${host}" \
            "mkdir -p '${DEST_DIR}' && chmod 700 '${DEST_DIR}'" || rc=$?
        if [[ $rc -eq 0 ]]; then
            scp -q -o BatchMode=yes -o ConnectTimeout=5 "${DEST}" "${host}:${DEST}.tmp" || rc=$?
        fi
        if [[ $rc -eq 0 ]]; then
            ssh -o BatchMode=yes -o ConnectTimeout=5 "${host}" \
                "chmod 600 '${DEST}.tmp' && mv -f '${DEST}.tmp' '${DEST}'" || rc=$?
        fi
        if [[ $rc -eq 0 ]]; then
            echo "render-secrets: pushed to ${host}:${DEST}"
        else
            failed_hosts+=("${host}")
            echo "render-secrets: FAILED push to ${host} (exit ${rc})" >&2
            if [[ $rc -eq 255 ]]; then
                echo "  ssh exit 255 usually means auth/network. Try:" >&2
                echo "    ssh-add -l         # are your keys loaded?" >&2
                echo "    ssh ${host} true   # does plain SSH work?" >&2
            fi
        fi
    done
    if [[ ${#failed_hosts[@]} -gt 0 ]]; then
        echo "render-secrets: push failures: ${failed_hosts[*]}" >&2
        exit 1
    fi
fi
