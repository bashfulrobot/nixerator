# PostToolUse output scrubber. Last line of defense against a secret reaching
# the transcript: it rewrites a Bash tool's result with token-shaped strings
# redacted BEFORE the model sees it, using the `updatedToolOutput` mechanism
# (verified in claude-code 2.1.216: input arrives at `.tool_response`, the
# rewrite field is `hookSpecificOutput.updatedToolOutput`, and the replacement
# must match the tool's output shape or it is discarded with "using original
# output"). We therefore mutate `.stdout`/`.stderr` in place and hand back the
# original object, so the shape is identical by construction.
#
# This complements guard-secret-commands.sh (which blocks the obvious leak
# commands up front). The guard can't see everything -- a wrapper bug, a
# `curl -v` the guard's pattern missed, an API response echoing a token -- so
# this net catches whatever slips through.
#
# Two redaction layers:
#   1. Literal values from secrets.json. Precise: zero false positives on git
#      SHAs / nix-store hashes, and it catches format-less tokens (Aha, Wave,
#      Forgejo) that no prefix pattern would recognize.
#   2. Known token-shaped prefixes (Slack xox*, GitHub ghp_/pat, Grafana glsa_,
#      1Password ops_, Google AIza, sk-*, JWTs, `Bearer <blob>`) as a backstop
#      for secrets that are not in secrets.json (e.g. a token fetched at runtime
#      or belonging to a customer).
#
# Fails open (best effort): if jq errors or secrets.json is unreadable it emits
# nothing and the original output passes. It never blocks a tool. Reading
# secret values into this subprocess is safe -- they are redacted OUT of the
# emitted JSON, never printed.
#
# wired into settings.json PostToolUse (matcher: Bash) at activation.

input="$(cat)"

secrets_file="${NIXOS_SECRETS_FILE:-${HOME}/.config/nixos-secrets/secrets.json}"

# Credential-looking scalar values from secrets.json: strings >= 16 chars that
# are not URLs or file paths (those aren't secrets and would be noisy to redact).
secret_values='[]'
if [[ -r "$secrets_file" ]]; then
  secret_values="$(jq -c '
    [ paths(scalars) as $p | getpath($p)
      | select(type == "string")
      | select(length >= 16)
      | select(test("://") | not)
      | select(test("^/") | not)
    ] | unique
  ' "$secrets_file" 2>/dev/null || echo '[]')"
fi

result="$(jq -c --argjson secrets "$secret_values" '
  # Escape regex metacharacters so a secret value matches literally under gsub.
  def reesc: gsub("(?<c>[.\\[\\]{}()?*+^$|\\\\/])"; "\\" + .c);

  def scrub:
    # 1. literal secret values (longest first, so a value never leaves a
    #    matchable substring of another)
    reduce ($secrets | sort_by(-length) | .[]) as $s (.;
      if ($s | length) >= 16 then gsub($s | reesc; "[REDACTED-SECRET]") else . end)
    # 2. known token-shaped prefixes
    | gsub("xox[a-z]-[A-Za-z0-9-]{8,}"; "[REDACTED-SLACK-TOKEN]")
    | gsub("gh[pousr]_[A-Za-z0-9]{20,}"; "[REDACTED-GH-TOKEN]")
    | gsub("github_pat_[A-Za-z0-9_]{20,}"; "[REDACTED-GH-TOKEN]")
    | gsub("glsa_[A-Za-z0-9_]{20,}"; "[REDACTED-GRAFANA-TOKEN]")
    | gsub("\\bops_[A-Za-z0-9]{40,}"; "[REDACTED-OP-TOKEN]")
    | gsub("\\bsk-[A-Za-z0-9_-]{20,}"; "[REDACTED-TOKEN]")
    | gsub("\\bAIza[A-Za-z0-9_-]{35}"; "[REDACTED-GOOGLE-KEY]")
    | gsub("eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}"; "[REDACTED-JWT]")
    | gsub("(?<pre>[Bb]earer\\s+)[A-Za-z0-9._~+/-]{16,}=*"; .pre + "[REDACTED-TOKEN]")
    | gsub("(?<pre>[Tt]oken\\s+)[A-Za-z0-9._~+/-]{24,}=*"; .pre + "[REDACTED-TOKEN]")
  ;

  .tool_response as $tr
  | if ($tr | type) == "object" and (($tr | has("stdout")) or ($tr | has("stderr")))
    then
      ( $tr
        | (if (.stdout | type) == "string" then .stdout |= scrub else . end)
        | (if (.stderr | type) == "string" then .stderr |= scrub else . end)
      ) as $new
      | if $new == $tr then empty
        else { hookSpecificOutput: { hookEventName: "PostToolUse", updatedToolOutput: $new } }
        end
    else empty
    end
' <<<"$input" 2>/dev/null || true)"

[[ -n "$result" ]] && printf '%s\n' "$result"
exit 0
