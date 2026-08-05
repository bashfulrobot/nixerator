# PreToolUse hard deny for an EnterWorktree(name=...) call that would collide
# with an existing worktree directory or the branch EnterWorktree itself
# creates (worktree-<name>).
#
# EnterWorktree does not error or auto-rename on a name collision -- it
# silently RESUMES whatever is already there, carrying over an earlier,
# unrelated session's commits (confirmed live while building this guard: a
# collided EnterWorktree call landed mid-way through someone else's clean,
# unpushed work, and the resuming session was evicted mid-command when a
# concurrent process cleaned that worktree up). The launch-time equivalent of
# this guarantee lives in the fish `__claude_worktree_name` helper
# (cfg/fish.nix), which loops to a guaranteed-free name before ever calling
# `claude --worktree`. This hook is the backstop for the case no wrapper
# script can reach: EnterWorktree called mid-session by an already-running
# agent (every background job does this by default). Every new worktree
# creation must get a name nothing else already holds -- a 1:1 worktree:agent
# mapping, never an accidental resume.
#
# Scope: only tool_input.name (create-a-new-worktree intent). A path-based
# call (switch into a specific existing worktree) is a deliberate, explicit
# resume and is never denied here -- see the EnterWorktree tool's own
# description for that path.
#
# Fails open on ambiguity: no name, no resolvable repo toplevel, or a git
# error all proceed rather than deny. A PreToolUse "deny" can never be
# overridden by another hook's "allow", so this composes safely with the
# other PreToolUse guards.
#
# wired into settings.json PreToolUse at activation (cfg/activation.nix).

input="$(cat)"
name="$(jq -r '.tool_input.name // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$name" ]] || exit 0

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$repo_root" ]] || exit 0

collides=false
[[ -e "$repo_root/.claude/worktrees/$name" ]] && collides=true
if git -C "$repo_root" rev-parse --verify --quiet "refs/heads/worktree-$name" >/dev/null 2>&1; then
  collides=true
fi
[[ "$collides" == true ]] || exit 0

suggestion="${name}-$(date +%H%M%S)"
jq -nc --arg name "$name" --arg suggestion "$suggestion" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("A worktree or branch named " + $name + " already exists. EnterWorktree does not error on a name collision, it resumes the existing worktree, which may hold another sessions unrelated, uncommitted work. Retry EnterWorktree with a different name, for example " + $suggestion + " -- or if resuming that exact worktree is genuinely intended, call EnterWorktree with path pointing at it instead of name.")
  }
}'
exit 0
