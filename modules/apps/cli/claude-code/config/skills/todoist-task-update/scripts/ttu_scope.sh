#!/usr/bin/env bash
# ttu_scope.sh — enumerate OPEN tasks across all Kong* projects (default) or one
# named project (optional arg, fuzzy substring). Emits [{task_id,title,project,url}].
# td-caller; read-only. `td task list` returns only incomplete tasks by default.
case $- in *x*)
  echo "refusing to run under set -x" >&2
  exit 2
  ;;
esac
set -euo pipefail

# Reuse todoist-triage's shared `td` rate-limit retry wrapper (sibling skill dir).
# Fall back to a passthrough so this script still runs if triage is absent.
_libtd="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../todoist-triage/scripts" 2>/dev/null && pwd)/lib_td.sh"
if [ -f "$_libtd" ]; then
  # shellcheck source=/dev/null
  . "$_libtd"
else
  td_retry() { td "$@"; }
fi

command -v td >/dev/null || {
  echo "td not found (todoist-cli skill)" >&2
  exit 127
}
command -v jq >/dev/null || {
  echo "jq not found" >&2
  exit 127
}

only="${1:-}"
projects=$(td_retry project list --json --all)
mapfile -t names < <(printf '%s' "$projects" | jq -r --arg only "$only" '
  .results[]
  | select(.name | test("^Kong"))
  | select($only == "" or (.name | ascii_downcase | contains($only | ascii_downcase)))
  | .name')

out='[]'
for pname in "${names[@]}"; do
  tasks=$(td_retry task list --project "$pname" --json --all 2>/dev/null || echo '{"results":[]}')
  out=$(jq -n --argjson acc "$out" --argjson t "$tasks" --arg p "$pname" '
    $acc + (($t.results // []) | map({task_id: .id, title: .content, project: $p, url: .url}))')
done
printf '%s\n' "$out"
