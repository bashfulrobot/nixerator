# PreToolUse permission gate for /auto and /github-issues-auto autonomous
# sessions.
#
# Sole arbiter for rm/kill/pkill: these are intentionally NOT in the settings
# ask/allow lists, so this hook decides their fate.
#
# kill/pkill: unchanged from the original design. While a session-bound
# sentinel is live, kill/pkill are auto-allowed against any process -- an
# autonomous troubleshooting run needs to reach for these against whatever is
# stuck, and there is no filesystem path to scope a process signal by.
# Otherwise they prompt, exactly as an ask rule would.
#
# rm: scoped to blast radius, not blanket. Even with a live sentinel, rm is
# only auto-allowed when every target path resolves inside a safe root, and
# "safe root" is mostly dynamic rather than a fixed list:
#
#   1. The session's own working tree. Read .cwd from the hook payload (the
#      same field precompact-checkpoint.sh already relies on) and, if it sits
#      inside a git repo or linked worktree, use that checkout's toplevel; if
#      not, use .cwd itself. Whatever folder or repo the autonomous run is
#      actually working in is its own blast-radius boundary -- a temp scratch
#      dir grants the whole temp dir, a worktree grants the whole worktree,
#      nothing outside it.
#   2. Pre-authorized folders. One absolute path per line in
#      $CLAUDE_CONFIG_DIR/auto-safe-roots (default ~/.claude/auto-safe-roots),
#      '#'-comments and blank lines ignored. Lets a folder outside the
#      session's own cwd be trusted ahead of time without a rebuild. Sanity
#      filtered on load: an entry that is itself catastrophic (see below), or
#      too shallow to be a meaningful scope (fewer than 3 path segments, e.g.
#      bare /home/<user>), is ignored rather than honoured.
#   3. A short list of universal scratch roots that make sense regardless of
#      cwd: /tmp, $HOME/.claude/jobs (background job scratch), and
#      $HOME/.claude/autonomous-runs (this skill's own log dir).
#
# A target outside all of the above, or one this hook cannot confidently
# resolve, falls through to "ask": the sentinel widens WHERE rm can run
# unattended, not whether it can run anywhere. On top of that, a circuit
# breaker denies rm against a short catastrophic-target list (bare /, bare
# $HOME, and system roots such as /etc, /nix, /boot) regardless of the
# sentinel, the cwd, or the pre-authorized file -- a hook "deny" can never be
# overridden by another hook's "allow", so this composes safely with the
# elevation logic below it.
#
# sudo is deliberately untouched here -- it stays an explicit ask rule and
# prompts in every mode. The permissions.deny list and the git guards are
# unaffected: a hook "allow" can never override a deny. Elevation fails
# closed (any resolution ambiguity yields "ask", never "allow"); the circuit
# breaker fails open on denial (only a confidently-resolved catastrophic
# target denies), matching the fail-open stance of the other guards in this
# directory.
#
# Parser scope: deliberately narrower than guard-primary-tree-write.sh's full
# cd-replay engine. An absolute or ~-prefixed rm target is always resolved,
# regardless of any cd/pushd elsewhere in the command, because it does not
# depend on cwd. A relative target is only resolved when the whole command
# contains no cd/pushd token at all (the common case: rm runs wherever the
# session's cwd already is, i.e. the same .cwd used for scope 1 above); if the
# command navigates, a relative rm target is left unresolved rather than
# guessed, which can only cost an unnecessary "ask", never a wrong "allow". A
# genuine rm invocation this hook's anchored matcher fails to isolate (heavily
# obfuscated quoting, eval, a here-doc body) falls back to the pre-existing
# sentinel-only decision -- no worse than before this scoping was added, just
# not improved by it either.
#
# wired into settings.json PreToolUse as @AUTO_GATE_COMMAND@ (cfg/activation.nix).
# git added to runtimeInputs alongside jq/gnugrep/coreutils for toplevel
# resolution (default.nix).

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$cmd" ]] || exit 0

# Fast path: neither rm, kill, nor pkill appears as a standalone word anywhere
# in the command. Nothing here to gate.
if ! grep -qE '(^|[[:space:]]|;|&&|\||\()(rm|kill|pkill)([[:space:]]|$)' <<<"$cmd"; then
  exit 0
fi

home="${HOME:-/root}"

# The session's actual working directory, per the hook payload -- not this
# subprocess's own $PWD, which the harness makes no guarantee matches the
# Bash tool's cwd. Same field precompact-checkpoint.sh already relies on.
# Used as the resolution base for every relative rm target below, and reused
# later (no second jq call) as the basis for the dynamic safe root.
sess_cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null || true)"

# True if $1 equals $2 or sits under it.
path_has_prefix() {
  local path="$1" prefix="$2"
  [[ "$path" == "$prefix" || "$path" == "$prefix"/* ]]
}

# Catastrophic circuit breaker: bare root, bare $HOME, and system dirs no
# legitimate Claude Code workflow ever needs to rm. Any OTHER user's home
# under /home is caught too; $HOME's own subtree is judged by the safe-root
# logic below, not this list, so ordinary work under $HOME still routes
# through the normal scoped-elevation/ask path instead of a hard deny.
is_catastrophic() {
  local p="$1" root
  [[ "$p" == "/" ]] && return 0
  [[ "$p" == "$home" ]] && return 0
  for root in /etc /boot /nix /usr /var /root /sys /proc /bin /sbin /lib /lib64; do
    path_has_prefix "$p" "$root" && return 0
  done
  if path_has_prefix "$p" /home && ! path_has_prefix "$p" "$home"; then
    return 0
  fi
  return 1
}

# Crude depth floor for pre-authorized entries: at least 3 path segments
# (e.g. /home/dustin/git, not bare /home/dustin), so the pre-authorized file
# can't be used to accidentally bless an entire home directory.
depth_ok() {
  local p="${1#/}" slashes
  slashes="${p//[^\/]/}"
  [[ "${#slashes}" -ge 2 ]]
}

has_nav="false"
if grep -qE '(^|[;&|(])[[:space:]]*(cd|pushd)([[:space:]]|$)' <<<"$cmd"; then
  has_nav="true"
fi

# Anchor rm the same way the other guards anchor git/stash: start of string, or
# right after a metacharacter that opens a new simple command, optionally
# preceded by env-assignment prefixes, plain wrappers, or compound-command
# heads (mirrors git_lead in guard-primary-tree-write.sh). An optional leading
# backslash catches the alias-bypassing \rm form.
rm_lead='(([A-Za-z_][A-Za-z0-9_]*=\S+|sudo|env|time|nice|nohup|command|exec|xargs|if|then|elif|else|while|until|do)\s+|(timeout|stdbuf)(\s+(-{1,2}\S+|[0-9]\S*))*\s+)*'
rm_re="(^|[;&|()\`{])\s*${rm_lead}\\\\?rm\b"

rm_invocations_found=0
rm_catastrophic="false"
rm_all_safe="true"
rm_targets=()

while IFS= read -r match; do
  [[ -n "$match" ]] || continue
  rm_invocations_found=$((rm_invocations_found + 1))
  moff="${match%%:*}"

  # Isolate this rm invocation from anything after it in the same compound
  # command, up to the next ; & | boundary.
  invocation="${cmd:moff}"
  invocation="${invocation%%[;&|]*}"

  read -ra tokens <<<"$invocation"
  past_rm="false"
  no_more_flags="false"
  target_count=0
  for tok in "${tokens[@]}"; do
    if [[ "$past_rm" == false ]]; then
      [[ "$tok" == "rm" || "$tok" == '\rm' ]] && past_rm="true"
      continue
    fi
    if [[ "$no_more_flags" == false && "$tok" == "--" ]]; then
      no_more_flags="true"
      continue
    fi
    if [[ "$no_more_flags" == false && "$tok" == -* ]]; then
      continue
    fi
    target_count=$((target_count + 1))

    resolved=""
    # The "~/"* pattern below matches the literal two-character prefix from
    # the untrusted command text (this token was never itself shell-expanded),
    # not an expanded path -- the quoting is deliberate here, not the SC2088
    # mistake that check normally catches.
    # shellcheck disable=SC2088
    case "$tok" in
      /*)
        resolved="$(realpath -m -- "$tok" 2>/dev/null || true)"
        ;;
      "~")
        resolved="$home"
        ;;
      "~/"*)
        resolved="$(realpath -m -- "$home/${tok#\~/}" 2>/dev/null || true)"
        ;;
      *)
        if [[ "$has_nav" == false && -n "$sess_cwd" ]]; then
          resolved="$(realpath -m -- "$sess_cwd/$tok" 2>/dev/null || true)"
        fi
        ;;
    esac

    if [[ -n "$resolved" ]] && is_catastrophic "$resolved"; then
      rm_catastrophic="true"
    fi
    if [[ -n "$resolved" ]]; then
      rm_targets+=("$resolved")
    else
      rm_all_safe="false"
    fi
  done
  # rm with zero resolvable targets (bare `rm -rf`, or a lone `--`) is not a
  # deletion the safe-root list can vouch for either way.
  [[ "$target_count" -gt 0 ]] || rm_all_safe="false"
done < <(grep -boP "$rm_re" <<<"$cmd" || true)

if [[ "$rm_catastrophic" == true ]]; then
  jq -nc '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "auto-gate: rm targets a protected system path -- denied regardless of any active /auto or /github-issues-auto session. If this is genuinely intended, run it yourself outside an autonomous session."}}'
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

    if [[ "$rm_invocations_found" -gt 0 ]]; then
      # Build the safe-root set lazily -- only needed once we know there is a
      # real rm to check under an active session, avoiding a git subprocess
      # call and a file read on every other elevated command. $sess_cwd was
      # already read above, for the same-cwd relative-target resolution.
      safe_roots=(/tmp "$home/.claude/jobs" "$home/.claude/autonomous-runs")

      if [[ -n "$sess_cwd" ]]; then
        toplevel="$(git -C "$sess_cwd" rev-parse --show-toplevel 2>/dev/null || true)"
        if [[ -n "$toplevel" ]]; then
          safe_roots+=("$toplevel")
        else
          resolved_cwd="$(realpath -m -- "$sess_cwd" 2>/dev/null || true)"
          [[ -n "$resolved_cwd" ]] && safe_roots+=("$resolved_cwd")
        fi
      fi

      roots_file="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/auto-safe-roots"
      if [[ -f "$roots_file" ]]; then
        while IFS= read -r line; do
          line="${line%%#*}"
          line="${line#"${line%%[![:space:]]*}"}"
          line="${line%"${line##*[![:space:]]}"}"
          [[ -n "$line" ]] || continue
          entry="$(realpath -m -- "$line" 2>/dev/null || true)"
          [[ -n "$entry" ]] || continue
          is_catastrophic "$entry" && continue
          depth_ok "$entry" || continue
          safe_roots+=("$entry")
        done <"$roots_file"
      fi

      for target in "${rm_targets[@]}"; do
        target_safe="false"
        for root in "${safe_roots[@]}"; do
          if path_has_prefix "$target" "$root"; then
            target_safe="true"
            break
          fi
        done
        [[ "$target_safe" == true ]] || rm_all_safe="false"
      done

      [[ "$rm_all_safe" == true ]] || decision="ask"
    fi
  fi
fi

reason="auto-gate: $decision for rm/kill/pkill"
if [[ "$decision" == "ask" && "$rm_invocations_found" -gt 0 && "$rm_all_safe" == false ]]; then
  reason="auto-gate: ask -- rm target is outside this session's working tree, the pre-authorized folders in \$CLAUDE_CONFIG_DIR/auto-safe-roots, and the universal scratch roots, even though an autonomous session is active"
fi

jq -nc --arg d "$decision" --arg reason "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $reason}}'
