# PostToolUse guard: nudge raw `nix` commands toward justfile recipes.
#
# This repo is justfile-only (auto-memory feedback_nixerator_justfile_only):
# rebuilds, upgrades, and eval go through `just` recipes, not raw nix. The
# deny-list already blocks nixos-rebuild + nix-collect-garbage; this only WARNS
# (never blocks) on other raw nix invocations so a genuine one-off still runs.
#
# Wired into settings.json PostToolUse via cfg/activation.nix (Nix-owned, stripped
# from capture in cfg/fish.nix). jq/gnugrep on PATH via runtimeInputs. Warn-level.

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$cmd" ]] || exit 0

# Skip if the command already goes through a `just` recipe.
if grep -qE '(^|[[:space:]]|;|&&|\|)just([[:space:]]|$)' <<<"$cmd"; then
  exit 0
fi

if grep -qE '(^|[[:space:]]|;|&&|\|)nix[[:space:]]+(build|eval|flake|develop|run|shell)([[:space:]]|$)' <<<"$cmd"; then
  echo "[raw-nix] NOTE: raw 'nix' command detected. This repo is justfile-only -- prefer a 'just' recipe (just qr / just qu / just check, etc.) where one exists. Use raw nix only for genuine one-offs."
fi
exit 0
