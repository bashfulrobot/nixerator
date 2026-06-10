#!/usr/bin/env bats
load helper

setup() {
  make_tmpdir
  mkdir -p "${TMP}/in" "${TMP}/out"
  echo "do-bill"  > "${TMP}/in/digitalocean-june.pdf"
  echo "gh-bill"  > "${TMP}/in/grasshopper.png"
}
teardown() { rm_tmpdir; }

@test "renames evidence by vendor code and builds the zip" {
  map="$(jq -nc --arg a "${TMP}/in/digitalocean-june.pdf" --arg b "${TMP}/in/grasshopper.png" \
        '{($a):"DO",($b):"GH"}')"
  run "${SCRIPTS}/package-evidence.sh" "${TMP}/out" 2026-06 BrMfg "${map}"
  [ "$status" -eq 0 ]
  [ -f "${TMP}/out/2026-06-DO.pdf" ]
  [ -f "${TMP}/out/2026-06-GH.png" ]
  [ -f "${TMP}/out/2026-06-BrMfg.zip" ]
}

@test "the zip contains the renamed files" {
  map="$(jq -nc --arg a "${TMP}/in/digitalocean-june.pdf" '{($a):"DO"}')"
  run "${SCRIPTS}/package-evidence.sh" "${TMP}/out" 2026-06 BrMfg "${map}"
  [ "$status" -eq 0 ]
  run bash -c "cd '${TMP}/out' && { command -v unzip >/dev/null 2>&1 && unzip -Z1 2026-06-BrMfg.zip || nix run nixpkgs#unzip -- -Z1 2026-06-BrMfg.zip; }"
  [[ "$output" == *"2026-06-DO.pdf"* ]]
}

@test "errors if a source file is missing" {
  map="$(jq -nc '{"/no/such/file.pdf":"DO"}')"
  run "${SCRIPTS}/package-evidence.sh" "${TMP}/out" 2026-06 BrMfg "${map}"
  [ "$status" -ne 0 ]
}
