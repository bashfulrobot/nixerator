#!/usr/bin/env bash
# package-evidence.sh OUTDIR PERIOD ISSUER MAP_JSON
#   MAP_JSON: {"/abs/path/to/source.ext":"VENDORCODE", ...}
# Renames each source into OUTDIR/<PERIOD>-<VENDOR>.<ext>, then zips them as
# OUTDIR/<PERIOD>-<ISSUER>.zip. Prints the zip path.
set -euo pipefail

OUTDIR="${1:?OUTDIR required}"
PERIOD="${2:?PERIOD required}"
ISSUER="${3:?ISSUER required}"
MAP="${4:?MAP_JSON required}"

# zip is not installed on all hosts; fall back to nixpkgs#zip.
zip_cmd() { if command -v zip >/dev/null 2>&1; then zip "$@"; else nix run nixpkgs#zip -- "$@"; fi; }

mkdir -p "${OUTDIR}"
renamed=()
while IFS=$'\t' read -r src vendor; do
  [ -f "${src}" ] || {
    echo "package-evidence: missing source '${src}'" >&2
    exit 1
  }
  ext="${src##*.}"
  dest="${OUTDIR}/${PERIOD}-${vendor}.${ext}"
  cp -- "${src}" "${dest}"
  renamed+=("$(basename "${dest}")")
done < <(echo "${MAP}" | jq -r 'to_entries[] | "\(.key)\t\(.value)"')

[ "${#renamed[@]}" -gt 0 ] || {
  echo "package-evidence: empty map" >&2
  exit 1
}

zipname="${PERIOD}-${ISSUER}.zip"
(cd "${OUTDIR}" && rm -f "${zipname}" && zip_cmd -q "${zipname}" "${renamed[@]}")
printf '%s\n' "${OUTDIR}/${zipname}"
