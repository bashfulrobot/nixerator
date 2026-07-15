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
  grep -q '^  token: tok-abc123$' "${THOME}/.config/tea/config.yml"
  grep -q '^  ssh_host: git.srvrs.co$' "${THOME}/.config/tea/config.yml"
  grep -q '^  user: bashfulrobot$' "${THOME}/.config/tea/config.yml"
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
  grep -q '^  token: NEW-tok$' "${THOME}/.config/tea/config.yml"
  ! grep -q 'OLD-tok' "${THOME}/.config/tea/config.yml"
}
