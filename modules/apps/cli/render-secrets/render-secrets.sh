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

# Hosts render-secrets is willing to scp to. Hardcoded — matches the same
# allow-list `justfile`'s remote-rebuild recipes use. Defends against a
# user typing (or pasting) an attacker hostname / `user@host` string and
# silently exfiltrating the rendered secrets via scp.
ALLOWED_HOSTS=(qbert donkeykong srv clanker)

# Document-backed files materialized from the `nixerator` vault onto this host,
# alongside the rendered secrets.json. Each entry is pipe-separated:
#   "<op document title>|<dest path>|<file mode>|<dir mode>|<guard>"
# The guard scopes WHERE a file lands:
#   - empty            -> every host that runs render-secrets.
#   - a path           -> only if that path exists (e.g. the consuming repo).
#   - "host:h1,h2,..." -> only on those hostnames.
# Behaviour per entry:
#   - guard fails        -> skip entirely (file never lands on this host).
#   - dest already there -> fix dest+dir perms, skip the fetch (never clobber).
#   - otherwise          -> op document get -> atomic write -> chmod.
# These are host-local identity files; --push never copies them (it only moves
# the rendered secrets.json). To add another, upload it as a Document item to the
# nixerator vault and add a row.
#
# Workstation hosts (archetypes.workstation.enable = true). Private SSH keys and
# per-repo git-crypt keys are scoped to these, so the pure server never gets them.
_WS="host:donkeykong,nixerator,qbert"
MATERIALIZE=(
  "homelab git-crypt key|${HOME}/.config/git-crypt/homelab.key|600|700|${HOME}/git/iac"

  # SSH private keys (workstations only)
  "id_ed25519|${HOME}/.ssh/id_ed25519|600|700|${_WS}"
  "id_ed25519_np|${HOME}/.ssh/id_ed25519_np|600|700|${_WS}"
  "id_rsa|${HOME}/.ssh/id_rsa|600|700|${_WS}"
  # SSH public keys
  "id_ed25519.pub|${HOME}/.ssh/id_ed25519.pub|644|700|${_WS}"
  "id_rsa.pub|${HOME}/.ssh/id_rsa.pub|644|700|${_WS}"
  "id_rsa_np.pub|${HOME}/.ssh/id_rsa_np.pub|644|700|${_WS}"

  # Per-repo git-crypt keys (workstations only)
  "mixerator-git-crypt-key|${HOME}/.ssh/mixerator-git-crypt-key|600|700|${_WS}"
  "nixcfg-git-crypt-key|${HOME}/.ssh/nixcfg-git-crypt-key|600|700|${_WS}"
  "nixerator-git-crypt-key|${HOME}/.ssh/nixerator-git-crypt-key|600|700|${_WS}"
  "talos-vms-git-crypt-key|${HOME}/.ssh/talos-vms-git-crypt-key|600|700|${_WS}"

  # Incus browser client certificate — public CRT, all Incus hosts.
  # Read by the Nix module via builtins.readFile at eval time to populate
  # the preseed trust store. 644 because it is a public key. Also listed
  # in PUSH_ALONGSIDE so --push propagates it alongside secrets.json.
  "incus-ui.crt|${HOME}/.config/incus/client.crt|644|700|"

  # Incus browser client certificate (PKCS12 bundle — private key inside).
  # Workstations only: needed for importing into a browser to authenticate
  # against the Incus web UI. srv is headless and has no browser.
  "incus-client.pfx|${HOME}/.config/incus/client.pfx|600|700|${_WS}"
)

# Files pushed alongside secrets.json when --push is used. Format per entry:
#   "<local src path>|<remote file mode>"
# Covers files needed at remote Nix eval time that MATERIALIZE only places
# locally. Each file is pushed only if it exists on the source host; missing
# files are silently skipped (bootstrap-safe). Atomic: staged as .tmp then
# mv'd, so a partial transfer never clobbers the live remote file.
PUSH_ALONGSIDE=(
  # Incus browser client CRT: needed on every Incus host at nix eval time
  # so builtins.readFile in the incus module can populate the preseed trust
  # store. MATERIALIZE places it locally; PUSH_ALONGSIDE carries it to peers.
  "${HOME}/.config/incus/client.crt|644"
)

usage() {
  cat >&2 <<EOF
Usage: render-secrets [--check] [--tpl PATH] [--push HOST [HOST...]]
  Renders 1Password-templated secrets to: ${DEST}
  Default template (baked at build time): ${TPL}

  --check          Render to a temp file and diff against the live file. No write.
  --tpl PATH       Override the template path. PATH must be inside the current
                   git working tree (refuses anything outside or symlinked out),
                   to prevent a hostile-cwd template from exfiltrating
                   arbitrary 1Password vault fields. Use this only when
                   intentionally editing the template in a worktree.
  --push HOST...   After rendering, scp the rendered file to each HOST at the
                   same path with 600 perms, then push any PUSH_ALONGSIDE files
                   that exist locally. HOST must be one of: ${ALLOWED_HOSTS[*]}.

Notes:
  --push requires at least one non-flag HOST immediately after it.
  Atomic writes — partial failures never leave DEST or remote files truncated.
EOF
  exit 2
}

# is_host_allowed HOST — true iff HOST is in the ALLOWED_HOSTS list (exact match).
is_host_allowed() {
  local h="$1" a
  for a in "${ALLOWED_HOSTS[@]}"; do
    [[ "$a" == "$h" ]] && return 0
  done
  return 1
}

# validate_tpl_path PATH — refuse the override unless PATH is a regular file
# (not a symlink), lives inside the cwd's git working tree, and is readable.
# Prevents two attacks: a hostile cwd dropping a `secrets.json.tpl` with
# arbitrary `op://` references, and a worktree template symlinked to a file
# outside the worktree.
validate_tpl_path() {
  local p="$1"
  if [[ ! -e "$p" ]]; then
    echo "render-secrets: --tpl path does not exist: $p" >&2
    exit 1
  fi
  if [[ -L "$p" ]]; then
    echo "render-secrets: --tpl refuses symlinked templates: $p" >&2
    exit 1
  fi
  if [[ ! -f "$p" ]]; then
    echo "render-secrets: --tpl path is not a regular file: $p" >&2
    exit 1
  fi
  local abs toplevel
  abs="$(realpath -e "$p")"
  toplevel="$(git -C "$(dirname "$abs")" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -z "$toplevel" ]]; then
    echo "render-secrets: --tpl path is not inside a git working tree: $p" >&2
    exit 1
  fi
  case "$abs" in
    "$toplevel"/*) : ;;
    *)
      echo "render-secrets: --tpl path is outside its git working tree: $p" >&2
      exit 1
      ;;
  esac
}

CHECK=0
PUSH=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK=1
      shift
      ;;
    --tpl)
      shift
      [[ $# -gt 0 && ! "$1" =~ ^- ]] || {
        echo "--tpl requires a PATH argument" >&2
        usage
      }
      validate_tpl_path "$1"
      TPL="$(realpath -e "$1")"
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
        if ! is_host_allowed "$1"; then
          echo "render-secrets: refusing to push to unrecognized host: $1" >&2
          echo "  Allowed: ${ALLOWED_HOSTS[*]}" >&2
          exit 1
        fi
        PUSH+=("$1")
        shift
      done
      ;;
    -h | --help)
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

# Service account auto-source. If OP_SERVICE_ACCOUNT_TOKEN is unset and a
# token file exists at the canonical path, use it — `op inject` then runs
# under the service account with zero biometric prompts. The token grants
# whatever the service account's vault scope allows (we deliberately scope
# the nixerator SA to read-only on the `nixerator` vault), so loose perms
# on the token file = full vault read. Refuse anything looser than 0600.
SA_TOKEN_FILE="${HOME}/.config/op/service-account-token"
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" && -f "${SA_TOKEN_FILE}" ]]; then
  sa_perms="$(stat -c '%a' "${SA_TOKEN_FILE}")"
  if [[ "${sa_perms}" != "600" ]]; then
    echo "render-secrets: ${SA_TOKEN_FILE} perms are ${sa_perms}, must be 600" >&2
    echo "  Fix:  chmod 600 ${SA_TOKEN_FILE}" >&2
    exit 1
  fi
  OP_SERVICE_ACCOUNT_TOKEN="$(<"${SA_TOKEN_FILE}")"
  export OP_SERVICE_ACCOUNT_TOKEN
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
  # --force: we created the tmp via mktemp so it already exists; without
  # --force op inject would prompt to confirm overwrite, which is impossible
  # under service-account auth (no TTY interaction).
  op inject --force -i "${TPL}" -o "${tmp}"
  chmod 600 "${tmp}"
  mv -f "${tmp}" "${out}"
  trap - RETURN
}

# guard_ok GUARD — true if GUARD is empty, a path that exists, or a
# "host:h1,h2,..." list that contains this hostname.
guard_ok() {
  local guard="$1"
  [[ -z "${guard}" ]] && return 0
  case "${guard}" in
    host:*)
      local cur hn _guard_hosts
      cur="$(hostname)"
      IFS=',' read -ra _guard_hosts <<<"${guard#host:}"
      for hn in "${_guard_hosts[@]}"; do
        [[ "${hn}" == "${cur}" ]] && return 0
      done
      return 1
      ;;
    *)
      [[ -e "${guard}" ]] && return 0
      return 1
      ;;
  esac
}

# materialize_one TITLE DEST FMODE DMODE [GUARD] — restore a 1Password Document
# item to DEST when it is not already there. Always fixes dir/file perms; never
# clobbers an existing DEST. Skipped if GUARD does not pass (see guard_ok).
# Returns non-zero on a fetch failure so the caller can warn without aborting
# the (already-written) secrets render.
materialize_one() {
  local title="$1" dest="$2" fmode="$3" dmode="$4" guard="${5:-}"
  local dir tmp
  guard_ok "${guard}" || return 0
  dir="$(dirname "${dest}")"
  mkdir -p "${dir}"
  chmod "${dmode}" "${dir}"
  if [[ -e "${dest}" ]]; then
    chmod "${fmode}" "${dest}"
    echo "render-secrets: ${dest} present (perms ${fmode}, skip fetch)"
    return 0
  fi
  tmp="$(mktemp -p "${dir}" .materialize.XXXXXX)"
  if ! op document get "${title}" --vault nixerator --out-file "${tmp}" --force; then
    rm -f "${tmp}"
    return 1
  fi
  chmod "${fmode}" "${tmp}"
  mv -f "${tmp}" "${dest}"
  echo "render-secrets: materialized ${dest}"
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
  # --force: we created the tmp via mktemp so it already exists; without
  # --force op inject would prompt to confirm overwrite, which is impossible
  # under service-account auth (no TTY interaction).
  op inject --force -i "${TPL}" -o "${tmp}"
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

# Restore document-backed host files (git-crypt keys, SSH keys, ...). Local
# only; a failure here warns but does not undo the secrets.json just rendered.
materialize_failed=()
for _m in "${MATERIALIZE[@]}"; do
  IFS='|' read -r _t _d _fm _dm _g <<<"${_m}"
  materialize_one "${_t}" "${_d}" "${_fm}" "${_dm}" "${_g}" ||
    materialize_failed+=("${_d}")
done

# Fallback: if incus client.crt failed to fetch from 1Password but client.pfx
# is present on disk, extract the certificate from the PKCS12 bundle. Incus
# generates the pfx with no passphrase. On workstations the pfx is materialized
# above; on headless hosts the crt must arrive via --push instead.
_incus_crt="${HOME}/.config/incus/client.crt"
_incus_pfx="${HOME}/.config/incus/client.pfx"
if [[ ! -f "${_incus_crt}" ]] && [[ -f "${_incus_pfx}" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    _crt_tmp="$(mktemp -p "$(dirname "${_incus_crt}")" .incus-crt.XXXXXX)"
    _ssl_err_file="${_crt_tmp}.err"
    trap 'rm -f "${_crt_tmp:-}" "${_ssl_err_file:-}"' EXIT
    # Try modern PKCS12 first; fall back to -legacy for bundles built with
    # older go-pkcs12 (RC2-40-CBC encryption, rejected by OpenSSL 3.x by default).
    # -clcerts: filter to client certs only, excluding CA bags from the bundle.
    _ssl_err1=""
    _ssl_err2=""
    if ! openssl pkcs12 -in "${_incus_pfx}" -nokeys -clcerts -passin pass: \
      -out "${_crt_tmp}" 2>"${_ssl_err_file}"; then
      _ssl_err1="$(cat "${_ssl_err_file}" 2>/dev/null)"
      _ssl_err2="$(openssl pkcs12 -in "${_incus_pfx}" -nokeys -clcerts -passin pass: \
        -legacy -out "${_crt_tmp}" 2>&1 || true)"
    fi
    rm -f "${_ssl_err_file}"
    _ssl_err_file=""
    if grep -q '-----BEGIN CERTIFICATE-----' "${_crt_tmp}" 2>/dev/null; then
      chmod 644 "${_crt_tmp}"
      mv -f "${_crt_tmp}" "${_incus_crt}"
      trap - EXIT
      echo "render-secrets: derived ${_incus_crt} from client.pfx"
      _mf_new=()
      for _f in "${materialize_failed[@]+"${materialize_failed[@]}"}"; do
        [[ "${_f}" != "${_incus_crt}" ]] && _mf_new+=("${_f}")
      done
      materialize_failed=("${_mf_new[@]+"${_mf_new[@]}"}")
    else
      rm -f "${_crt_tmp}"
      trap - EXIT
      _ssl_combined="${_ssl_err1:+modern: ${_ssl_err1}}${_ssl_err1:+${_ssl_err2:+; }}${_ssl_err2:+legacy: ${_ssl_err2}}"
      echo "render-secrets: WARNING: openssl could not extract cert from client.pfx${_ssl_combined:+: ${_ssl_combined}}" >&2
    fi
  else
    echo "render-secrets: WARNING: openssl not in PATH; cannot derive ${_incus_crt} from client.pfx" >&2
  fi
fi

if [[ ${#materialize_failed[@]} -gt 0 ]]; then
  echo "render-secrets: FAILED to materialize: ${materialize_failed[*]}" >&2
fi

if [[ ${#PUSH[@]} -gt 0 ]]; then
  # Track per-host outcome so a mid-list failure doesn't silently skip the
  # rest. We still exit non-zero at the end if any host failed.
  failed_hosts=()
  for host in "${PUSH[@]}"; do
    echo "render-secrets: pushing to ${host}..."
    rc=0
    # Stage to ${DEST}.tmp on the remote (same dir as DEST, same fs), then
    # atomically mv. Partial scp leaves DEST untouched.
    ssh -o BatchMode=yes -o ConnectTimeout=5 -- "${host}" \
      "mkdir -p '${DEST_DIR}' && chmod 700 '${DEST_DIR}'" || rc=$?
    if [[ $rc -eq 0 ]]; then
      scp -q -o BatchMode=yes -o ConnectTimeout=5 -- "${DEST}" "${host}:${DEST}.tmp" || rc=$?
    fi
    if [[ $rc -eq 0 ]]; then
      ssh -o BatchMode=yes -o ConnectTimeout=5 -- "${host}" \
        "chmod 600 '${DEST}.tmp' && mv -f '${DEST}.tmp' '${DEST}'" || rc=$?
    fi
    if [[ $rc -eq 0 ]]; then
      echo "render-secrets: pushed to ${host}:${DEST}"
      # Push any PUSH_ALONGSIDE files that exist locally. Failures are
      # tracked in failed_hosts but don't abort the remaining hosts.
      for _pa in "${PUSH_ALONGSIDE[@]}"; do
        IFS='|' read -r _pa_src _pa_mode <<<"${_pa}"
        [[ -f "${_pa_src}" ]] || continue
        _pa_dir="$(dirname "${_pa_src}")"
        _pa_rc=0
        ssh -o BatchMode=yes -o ConnectTimeout=5 -- "${host}" \
          "mkdir -p '${_pa_dir}'" || _pa_rc=$?
        if [[ $_pa_rc -eq 0 ]]; then
          scp -q -o BatchMode=yes -o ConnectTimeout=5 -- \
            "${_pa_src}" "${host}:${_pa_src}.tmp" || _pa_rc=$?
        fi
        if [[ $_pa_rc -eq 0 ]]; then
          ssh -o BatchMode=yes -o ConnectTimeout=5 -- "${host}" \
            "chmod ${_pa_mode} '${_pa_src}.tmp' && mv -f '${_pa_src}.tmp' '${_pa_src}'" || _pa_rc=$?
        fi
        if [[ $_pa_rc -eq 0 ]]; then
          echo "render-secrets: pushed $(basename "${_pa_src}") to ${host}"
        else
          failed_hosts+=("${host}:$(basename "${_pa_src}")")
          echo "render-secrets: FAILED push of $(basename "${_pa_src}") to ${host} (exit ${_pa_rc})" >&2
        fi
      done
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

# Surface a materialize failure in the exit status, after any push handling.
if [[ ${#materialize_failed[@]} -gt 0 ]]; then
  exit 1
fi
