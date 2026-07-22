#!/usr/bin/env bash
# ttu_scope.sh — enumerate OPEN tasks across all Kong* projects (default) or one
# named project (optional arg, fuzzy substring). Emits [{task_id,title,project,url}].
# td-caller; read-only. `td task list` returns only incomplete tasks by default.
case $- in *x*) echo "refusing to run under set -x" >&2; exit 2;; esac
set -euo pipefail
command -v td >/dev/null || { echo "td not found (todoist-cli skill)" >&2; exit 127; }
command -v jq >/dev/null || { echo "jq not found" >&2; exit 127; }

only="${1:-}"
projects=$(td project list --json --all)
mapfile -t names < <(printf '%s' "$projects" | jq -r --arg only "$only" '
  .results[]
  | select(.name | test("^Kong"))
  | select($only == "" or (.name | ascii_downcase | contains($only | ascii_downcase)))
  | .name')

out='[]'
for pname in "${names[@]}"; do
  tasks=$(td task list --project "$pname" --json --all 2>/dev/null || echo '{"results":[]}')
  out=$(jq -n --argjson acc "$out" --argjson t "$tasks" --arg p "$pname" '
    $acc + (($t.results // []) | map({task_id: .id, title: .content, project: $p, url: .url}))')
done
printf '%s\n' "$out"
