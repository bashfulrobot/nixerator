#!/usr/bin/env bats
# Regression tests for render-secrets' Forgejo `tea` login-config generation.
#
# Background: the tea config used to be written by a Nix home.activation script.
# Activation only re-runs when the Nix generation changes, so a rotated token
# (rendered into secrets.json, no generation change) never reached the config
# until the next generation-changing rebuild. The fix moves generation into
# render-secrets, which runs exactly when the token changes. These tests pin
# that behaviour: written when the token is present, skipped (never clobbered)
# when it is absent, and overwritten on rotation.
load helper

setup() { setup_home; }
teardown() { rm_home; }

@test "writes tea config when .forgejo.apiToken is present" {
  printf '{"forgejo":{"apiToken":"tok-abc123"}}' >"${THOME}/secrets.json"
  run tea_gen "${THOME}/secrets.json"
  [ "$status" -eq 0 ]
  [ -f "${THOME}/.config/tea/config.yml" ]
  [ "$(stat -c '%a' "${THOME}/.config/tea/config.yml")" = "600" ]
  grep -q '^- name: srvrs$' "${THOME}/.config/tea/config.yml"
  grep -q '^  url: https://git.srvrs.co$' "${THOME}/.config/tea/config.yml"
  grep -q "^  token: 'tok-abc123'\$" "${THOME}/.config/tea/config.yml"
  grep -q '^  ssh_host: git.srvrs.co$' "${THOME}/.config/tea/config.yml"
  grep -q '^  user: bashfulrobot$' "${THOME}/.config/tea/config.yml"
}

@test "no-arg call falls back to DEST" {
  printf '{"forgejo":{"apiToken":"tok-from-dest"}}' >"${THOME}/secrets.json"
  run tea_gen_default "${THOME}/secrets.json"
  [ "$status" -eq 0 ]
  grep -q "^  token: 'tok-from-dest'\$" "${THOME}/.config/tea/config.yml"
}

@test "special-character token is written verbatim inside the quoted scalar" {
  # % must not be read as a printf directive; backslash must survive; a single
  # quote must be doubled so the YAML scalar stays well-formed.
  printf '{"forgejo":{"apiToken":"a%%b\\\\c'\''d"}}' >"${THOME}/secrets.json"
  run tea_gen "${THOME}/secrets.json"
  [ "$status" -eq 0 ]
  # YAML single-quoted scalar: the embedded ' is doubled on disk.
  grep -qF "  token: 'a%b\\c''d'" "${THOME}/.config/tea/config.yml"
}

@test "refuses to write when the token contains a newline" {
  printf '{"forgejo":{"apiToken":"tok\\nname: evil"}}' >"${THOME}/secrets.json"
  run tea_gen "${THOME}/secrets.json"
  [ "$status" -ne 0 ]
  [ ! -e "${THOME}/.config/tea/config.yml" ]
  [ -z "$(find "${THOME}/.config/tea" -name '.tea-config.*' 2>/dev/null)" ]
}

@test "skips (writes nothing) when the forgejo key is absent" {
  printf '{"grafana":{"token":"x"}}' >"${THOME}/secrets.json"
  run tea_gen "${THOME}/secrets.json"
  [ "$status" -eq 0 ]
  [ ! -e "${THOME}/.config/tea/config.yml" ]
}

@test "skips when apiToken is an empty string" {
  printf '{"forgejo":{"apiToken":""}}' >"${THOME}/secrets.json"
  run tea_gen "${THOME}/secrets.json"
  [ "$status" -eq 0 ]
  [ ! -e "${THOME}/.config/tea/config.yml" ]
}

@test "does not clobber an existing config when the token is absent" {
  mkdir -p "${THOME}/.config/tea"
  printf 'preexisting\n' >"${THOME}/.config/tea/config.yml"
  printf '{}' >"${THOME}/secrets.json"
  run tea_gen "${THOME}/secrets.json"
  [ "$status" -eq 0 ]
  grep -q '^preexisting$' "${THOME}/.config/tea/config.yml"
}

@test "rotation: overwrites an existing config with the new token" {
  mkdir -p "${THOME}/.config/tea"
  printf 'logins:\n- name: srvrs\n  token: OLD-tok\n' >"${THOME}/.config/tea/config.yml"
  printf '{"forgejo":{"apiToken":"NEW-tok"}}' >"${THOME}/secrets.json"
  run tea_gen "${THOME}/secrets.json"
  [ "$status" -eq 0 ]
  grep -q "^  token: 'NEW-tok'\$" "${THOME}/.config/tea/config.yml"
  ! grep -q 'OLD-tok' "${THOME}/.config/tea/config.yml"
}
