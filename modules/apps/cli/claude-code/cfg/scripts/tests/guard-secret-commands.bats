#!/usr/bin/env bats
# Regression tests for guard-secret-commands.sh, the PreToolUse deny hook that
# blocks Bash commands which would print a secret into the transcript.
#
# The hook is nothing but a set of PCRE matchers, so it is exactly the kind of
# thing that silently rots: a tightened pattern that starts blocking the safe
# `[ -n "${TOK:-}" ] && echo set` idiom, or a loosened one that stops catching
# `echo $AHA_API_TOKEN`. These cases pin both directions. The two "safe pattern"
# allow cases (presence check, and the -K <(printf ...) header idiom) are the
# ones most likely to regress into false positives.

HOOK="${BATS_TEST_DIRNAME}/../guard-secret-commands.sh"

# Echo the hook's decision (deny/allow) for a given command string.
decision() {
  local json out
  json="$(jq -nc --arg c "$1" '{tool_input:{command:$c}}')"
  out="$(printf '%s' "$json" | bash "$HOOK" 2>/dev/null)"
  if grep -q '"permissionDecision":"deny"' <<<"$out"; then echo deny; else echo allow; fi
}

@test "denies commands that would print a secret" {
  local fails=0 cmd
  local deny_cases=(
    'echo $AHA_API_TOKEN'
    'echo "${AHA_API_TOKEN:-no}"'
    'echo ${GRAFANA_TOKEN}'
    'printenv AHA_API_TOKEN'
    'env'
    'env | grep AHA'
    'printenv'
    'set'
    'true; set'
    'export -p'
    'declare -x'
    'cat ~/.config/nixos-secrets/secrets.json'
    'grep aha ~/.config/nixos-secrets/secrets.json'
    'head -5 /home/dustin/.config/nixos-secrets/secrets.json'
    'cat ~/.config/slack/credentials.json'
    'cat ~/.ssh/id_ed25519'
    'op read op://vault/item/field'
    'op item get foo --reveal'
    'sf org display --json'
    'sf org display --verbose'
    'gws auth export'
    'curl -v https://api.example.com'
    'curl -sSv https://api.example.com/x'
    'curl --verbose https://x'
    'set -x'
    'set -euxo pipefail'
    'bash -x ./script.sh'
  )
  for cmd in "${deny_cases[@]}"; do
    if [ "$(decision "$cmd")" != deny ]; then
      echo "EXPECTED DENY, GOT ALLOW: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}

@test "allows safe commands (no false positives)" {
  local fails=0 cmd
  local allow_cases=(
    'echo hello'
    'echo $PATH'
    '[ -n "${AHA_API_TOKEN:-}" ] && echo set || echo unset'
    ': "${AHA_API_TOKEN:?missing}"'
    'env FOO=bar mycmd'
    '/usr/bin/env python script.py'
    'set -euo pipefail'
    "jq 'keys' ~/.config/nixos-secrets/secrets.json"
    'git commit -m "add token validation"'
    'cat README.md'
    'printenv PATH'
    'sf org display'
    'curl https://api.example.com/v1/things -H "Accept: json"'
    'grep env modules/foo.nix'
    'echo "please set the token here"'
    'cat ~/.ssh/id_ed25519.pub'
    'curl -K <(printf "header=\"Authorization: Bearer %s\"\n" "$FORGEJO_TOKEN") https://x'
  )
  for cmd in "${allow_cases[@]}"; do
    if [ "$(decision "$cmd")" != allow ]; then
      echo "EXPECTED ALLOW, GOT DENY: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}
