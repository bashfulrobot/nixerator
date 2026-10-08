#!/usr/bin/env bats
# bump-plugin-marketplace-sha.sh: for key claude-skills it rewrites the sha pin
# AND snapshots claude-stack/resolved/{qbert,srv}.json (fetched with `gh api`)
# into cfg/claude-stack/, both from the same sha. gh is stubbed; no network.

setup() {
  TMP="$(mktemp -d)"
  mkdir -p "$TMP/cfg/scripts" "$TMP/bin"
  cp "${BATS_TEST_DIRNAME}/../bump-plugin-marketplace-sha.sh" "$TMP/cfg/scripts/"
  cat >"$TMP/cfg/plugin-config.nix" <<'NIX'
  selfPins = {
    claude-skills.source = {
      source = "github";
      repo = "bashfulrobot/claude-skills";
      sha = "1111111111111111111111111111111111111111";
    };
  };
NIX
  # Stub gh: emit a valid resolved file for whichever host is in the URL.
  cat >"$TMP/bin/gh" <<'SH'
#!/usr/bin/env bash
url="${*: -1}"
host="${url##*/}"; host="${host%%.json*}"
if [[ -n "${GH_FAIL:-}" ]]; then exit 1; fi
printf '{"schemaVersion":1,"host":"%s","plugins":{}}\n' "$host"
SH
  chmod +x "$TMP/bin/gh"
  export PATH="$TMP/bin:$PATH"
  NEW=2222222222222222222222222222222222222222
}

teardown() { rm -rf "$TMP"; }

@test "claude-skills: pin and snapshot are written together at the given sha" {
  run bash "$TMP/cfg/scripts/bump-plugin-marketplace-sha.sh" claude-skills bashfulrobot/claude-skills "$NEW"
  [ "$status" -eq 0 ]
  grep -q "$NEW" "$TMP/cfg/plugin-config.nix"
  [ "$(jq -r .host "$TMP/cfg/claude-stack/qbert.json")" = qbert ]
  [ "$(jq -r .host "$TMP/cfg/claude-stack/srv.json")" = srv ]
}

@test "claude-skills: a failed fetch leaves the pin and snapshot untouched" {
  GH_FAIL=1 run bash "$TMP/cfg/scripts/bump-plugin-marketplace-sha.sh" claude-skills bashfulrobot/claude-skills "$NEW"
  [ "$status" -ne 0 ]
  grep -q 1111111111111111111111111111111111111111 "$TMP/cfg/plugin-config.nix"
  [ ! -e "$TMP/cfg/claude-stack/qbert.json" ]
}
