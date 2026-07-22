# PreToolUse hard block for commands that would print a secret into the
# transcript. The transcript is model context, so any token/password reaching a
# Bash tool's stdout/stderr is effectively exfiltrated. This denies the whole
# leak-command class BEFORE it runs, which is the only reliable defense against
# an agent improvising its own preflight -- the documented root cause of the one
# leak we have seen (an agent ran `echo ${AHA_API_TOKEN:-no}`, which prints the
# token when the variable is set).
#
# A PreToolUse "deny" can never be overridden by another hook's "allow" or by a
# permissions allow-list entry, so this closes the `env`/`cat secrets.json`
# holes even though those commands are still allow-listed in settings.json.
#
# Design constraints, learned the hard way:
#   - Anchor bare-command matches (env/printenv/set) to command position with
#     ${cmdstart}, so `echo set ||` (the SAFE presence-check idiom) and
#     `grep env` are not mistaken for a dump.
#   - Rule 1 matches echo/print but NOT printf, so the gold-standard
#     `curl -K <(printf 'header="Authorization: Bearer %s"\n' "$TOK")` header
#     idiom is never blocked.
# Fails open on ambiguity: only a positive match denies. Every reason names the
# safe alternative so the agent can re-route rather than get stuck.
#
# wired into settings.json PreToolUse at activation (cfg/activation.nix).

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$cmd" ]] || exit 0

deny() {
  jq -nc --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Names that mark a variable/field as a credential. Case-insensitive.
secret='(TOKEN|SECRET|PASSWORD|PASSWD|API[_-]?KEY|APIKEY|CREDENTIAL|ACCESS[_-]?KEY|PRIVATE[_-]?KEY|XOXC|XOXD|BEARER|OP_SERVICE_ACCOUNT)'
# A command starts at string start, after a separator (; & | (), or inside a
# backtick substitution -- never after a bare space (that means it is an arg).
cmdstart='(^|[;&|(]|`)\s*'

# 1. echo/print of a secret-named variable -- the exact leak that happened.
#    Catches `echo $AHA_API_TOKEN`, `echo "${AHA_API_TOKEN:-no}"`, and
#    `printenv AHA_API_TOKEN`. printf is excluded on purpose (see header).
if grep -qiP "\\b(echo|print|printenv)\\b[^|;&]*\\\$\\{?[A-Za-z_]*${secret}" <<<"$cmd" \
  || grep -qiP "\\bprintenv\\b[^|;&]*\\b[A-Za-z_]*${secret}" <<<"$cmd"; then
  deny "Refusing: this prints a secret-named variable to stdout, which lands in the transcript (model context). To check a token exists without printing it: [ -n \"\${TOK:-}\" ] && echo set || echo unset"
fi

# 2. Dump the whole environment. Anchored to command position so `env FOO=bar
#    cmd`, `env python`, and `grep env` all proceed; only a bare env/printenv/set
#    dump (or export -p / declare -x) matches.
if grep -qP "${cmdstart}env\\s*(\$|[|;&>])" <<<"$cmd" \
  || grep -qP "${cmdstart}printenv\\s*(\$|[|;&>])" <<<"$cmd" \
  || grep -qP "${cmdstart}set\\s*(\$|\\|)" <<<"$cmd" \
  || grep -qP '\b(export\s+-p|declare\s+-[px]|typeset\s+-[px])\b' <<<"$cmd"; then
  deny "Refusing: dumping the environment prints every rendered secret (AHA_API_TOKEN, WAVE_FULL_ACCESS_TOKEN, FORGEJO_TOKEN, ...) into the transcript. Read the specific non-secret var you need by name instead."
fi

# 3. Raw read of a known secret file. jq is intentionally NOT matched, so the
#    safe structural inspection `jq 'keys' secrets.json` still works. Public
#    keys (id_*.pub) are excluded.
if grep -qiP '\b(cat|bat|nl|less|more|head|tail|tac|strings|xxd|od|hexdump|base64|cut|awk|sed|grep|rg|ag)\b[^|;&]*(secrets\.json|nixos-secrets|service-account-token|/\.config/op/|credentials\.json|\.ssh/id_[A-Za-z0-9_]++(?!\.pub))' <<<"$cmd"; then
  deny "Refusing: this dumps a secrets/credentials file into the transcript. Inspect structure with jq 'keys' only, or check existence with test -f -- never print the values."
fi

# 4. 1Password value reveal.
if grep -qP '\bop\s+read\b' <<<"$cmd" \
  || grep -qP '\bop\s+item\s+get\b[^|;&]*--reveal' <<<"$cmd"; then
  deny "Refusing: op read / op item get --reveal surfaces the secret value into context. Use item titles, field labels, and op:// paths only, or move a value blind with op item edit dest=\"\$(op read ...)\"."
fi

# 5. Salesforce access-token exposure. `sf org display --json` and `--verbose`
#    both include result.accessToken.
if grep -qP '\bsf\s+org\s+display\b[^|;&]*(--json|--verbose)' <<<"$cmd"; then
  deny "Refusing: sf org display --json/--verbose includes the live accessToken. Check auth with sf org display piped through a jq filter that selects only alias/username/instanceUrl."
fi

# 6. gws OAuth credential dump.
if grep -qP '\bgws\s+auth\s+export\b' <<<"$cmd"; then
  deny "Refusing: gws auth export dumps the OAuth access+refresh token. Use gws auth status (prints only storage/token_valid) to check auth."
fi

# 7. curl trace/verbose dumps the Authorization header.
if grep -qP '\bcurl\b[^|;&]*(\s-[a-zA-Z]*v[a-zA-Z]*(\s|$)|--verbose\b|--trace(-ascii)?\b)' <<<"$cmd"; then
  deny "Refusing: curl -v/--verbose/--trace prints request headers, including Authorization: Bearer <token>. Drop the verbose flag; use -w '%{http_code}' if you only need the status."
fi

# 8. Shell xtrace expands secret variables (including auth headers) to stderr.
if grep -qP '\b(set\s+-[a-zA-Z]*x|bash\s+-[a-zA-Z]*x|sh\s+-[a-zA-Z]*x)' <<<"$cmd"; then
  deny "Refusing: set -x / bash -x traces every expansion, including Authorization headers built from a token. Debug without xtrace, or add a targeted echo of a non-secret value."
fi

exit 0
