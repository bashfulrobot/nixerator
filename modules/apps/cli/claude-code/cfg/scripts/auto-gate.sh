# PreToolUse permission gate for /auto autonomous sessions.
#
# Sole arbiter for rm/kill/pkill: these are intentionally NOT in the settings
# ask/allow lists, so this hook decides their fate. While a session-bound
# sentinel is live, those commands are auto-allowed (hands-off autonomous
# runs); otherwise they prompt, exactly as an ask rule would. sudo is
# deliberately untouched here -- it stays an explicit ask rule and prompts in
# every mode. The deny list and git guards are unaffected: a hook "allow" can
# never override a deny. Fails closed -- any ambiguity yields "ask".
#
# wired into settings.json PreToolUse as @AUTO_GATE_COMMAND@ (cfg/activation.nix).

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$cmd" ]] || exit 0

# Match rm / kill / pkill only as standalone words (not npm, charm, terminal).
if ! grep -qE '(^|[[:space:]]|;|&&|\||\()(rm|kill|pkill)([[:space:]]|$)' <<<"$cmd"; then
  exit 0
fi

sentinel="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.auto-mode-active"
decision="ask"
if [[ -f "$sentinel" ]]; then
  # Bind the grant to THIS session: a stale sentinel from a crashed run carries
  # a different session id and therefore can never elevate another session.
  sid="$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null || true)"
  ssid="$(jq -r '.session_id // empty' "$sentinel" 2>/dev/null || true)"
  if [[ -n "$sid" && "$sid" == "$ssid" ]]; then
    decision="allow"
  fi
fi

jq -nc --arg d "$decision" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: ("auto-gate: " + $d + " for rm/kill/pkill")}}'
