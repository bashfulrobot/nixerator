# The permissions.allow pass cfg/activation.nix runs over
# ~/.claude/settings.json, in both apps.cli.claude-code.stackApply modes.
#
# Arguments the caller passes:
#
#   --argjson   stack_apply true|false   apps.cli.claude-code.stackApply.enable
#   --slurpfile decl <claude-stack-permissions.json>   the manifest's rules for
#                                                      this host (off path only)
#
# Covered by cfg/scripts/tests/activation-allow.bats. In its own file, like
# cfg/scripts/canonicalize-settings.jq, so bats runs the real filter.

# `X(a:*)` and `X(a *)` are the same rule. The manifest normalises to the second
# spelling, so a legacy-syntax live rule must not be duplicated by the union.
def norm: sub(":\\*\\)$"; " *)");

# stackApply off: ADD-ONLY ordered union. permissions.allow is runtime-owned
# (rules approved in a session are captured into config/settings.json), so this
# removes nothing: live rules keep their order and declared rules not already
# present are appended in manifest order. Idempotent.
def union_declared:
  (.permissions.allow // []) as $cur
  | ($cur | map(norm)) as $have
  | .permissions.allow = ($cur + [($decl[0] // [])[] | select(norm as $n | $have | any(. == $n) | not)]);

# stackApply on: the claude-skills manifest owns the list. Drop the block the
# sed in cfg/activation.nix copied out of config/settings.json so that
# `claude_stack.py apply`, which runs after this, is the only writer. The result
# is the same under either apply: the merged claude-skills branch replaces the
# live list, and the pinned add-only revision unions the declared rules into an
# empty one. See .claude/docs/claude-stack-apply.md.
if $stack_apply then
  del(.permissions.allow)
else
  union_declared
end
