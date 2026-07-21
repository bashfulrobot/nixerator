#!/usr/bin/env bash
# forge — provider-aware git-forge helper.
#
# One thin CLI that speaks to whichever forge the current repo's `origin`
# remote points at: GitHub (via `gh`) or a self-hosted Forgejo/Gitea (via its
# REST API + $FORGEJO_TOKEN). Skills call `forge <verb>` instead of `gh`
# directly, so the gh-vs-Forgejo divergence lives in exactly one file.
#
# Scope: only the portable verbs the skills actually share. GitHub-specific
# automation (CI-gated auto-merge, reviewDecision/mergeStateStatus polling)
# stays in the skills behind a `[ "$(forge host)" = github ]` guard — this
# helper does not fake Forgejo parity for concepts Forgejo models differently.
#
# Forgejo auth: FORGEJO_TOKEN + FORGEJO_URL, exported by the fish module from
# the render-secrets blob. The token is high-privilege, so writes go through
# the same verbs the skills already gate behind their preview/confirm prompts.
#
# Output contract: read verbs that return structured data emit a NORMALISED
# JSON object with provider-neutral keys (number, title, body, base, head,
# headSha, url, state, ...), so callers parse one shape regardless of host.

set -euo pipefail

_die() {
  echo "forge: $*" >&2
  exit 1
}

# Issue and PR numbers get interpolated straight into REST URL paths, so a
# non-numeric value is a path-injection vector. Reject anything that is not a
# run of digits before it reaches a request.
_require_num() {
  [[ "$1" =~ ^[0-9]+$ ]] || _die "expected a numeric issue/PR number, got '$1'"
}

# --- remote / host / repo ----------------------------------------------------

_remote_url() {
  git remote get-url origin 2>/dev/null || _die "no 'origin' remote in $(pwd)"
}

# Host of a URL: strips scheme + user@, keeps up to the first / or :.
_url_host() {
  # shellcheck disable=SC2001
  echo "$1" | sed -E 's#^[a-z]+://##; s#^[^@]*@##; s#[:/].*$##'
}

# host -> github | forgejo. GitHub is github.com; Forgejo is whatever host
# $FORGEJO_URL points at, so renaming the instance needs no change here.
_host() {
  local rhost fhost
  rhost="$(_url_host "$(_remote_url)")"
  case "$rhost" in
    github.com)
      echo github
      return
      ;;
  esac
  if [ -n "${FORGEJO_URL:-}" ]; then
    fhost="$(_url_host "$FORGEJO_URL")"
    [ "$rhost" = "$fhost" ] && {
      echo forgejo
      return
    }
  fi
  _die "unrecognised git host '$rhost' (not github.com, not \$FORGEJO_URL)"
}

# owner/name from either ssh (git@host:owner/repo.git) or https form.
_repo() {
  local u
  u="$(_remote_url)"
  u="${u%.git}"
  # shellcheck disable=SC2001
  echo "$u" | sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#'
}

_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null || _die "not on a branch"
}

# --- Forgejo REST ------------------------------------------------------------

# The Authorization header carries a high-privilege token, so it must never
# land on curl's argv (any local user could read it from /proc/<pid>/cmdline).
# We hand curl the header through a -K config file on a process-substitution fd
# built by the `printf` BUILTIN, so the token stays inside this shell and never
# becomes another process's argument. The fd is separate from stdin, so a
# request body passed via --data still works.
_fj_auth_config() {
  printf 'header = "Authorization: token %s"\n' "$FORGEJO_TOKEN"
}

# _fj METHOD PATH [JSON_BODY] — JSON request against the Gitea-compatible API.
_fj() {
  local method="$1" path="$2" body="${3:-}"
  : "${FORGEJO_URL:?FORGEJO_URL not set}"
  : "${FORGEJO_TOKEN:?FORGEJO_TOKEN not set — run: just render-secrets, then start a new shell}"
  local url="${FORGEJO_URL%/}/api/v1/${path}"
  if [ -n "$body" ]; then
    curl -fsS -X "$method" \
      -K <(_fj_auth_config) \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      --data "$body" "$url"
  else
    curl -fsS -X "$method" \
      -K <(_fj_auth_config) \
      -H "Accept: application/json" \
      "$url"
  fi
}

# _fj_raw PATH — non-JSON GET (e.g. a .diff), returns the body verbatim.
_fj_raw() {
  : "${FORGEJO_URL:?FORGEJO_URL not set}"
  : "${FORGEJO_TOKEN:?FORGEJO_TOKEN not set — run: just render-secrets}"
  curl -fsS \
    -K <(_fj_auth_config) \
    "${FORGEJO_URL%/}/api/v1/${1}"
}

# Resolve label NAMES (args) to Forgejo label IDs (one per line).
_fj_label_ids() {
  local repo names_json
  repo="$(_repo)"
  names_json="$(printf '%s\n' "$@" | jq -R . | jq -sc .)"
  _fj GET "repos/${repo}/labels?limit=100" |
    jq --argjson want "$names_json" '[.[] | select(.name as $n | $want | index($n)) | .id]'
}

# Resolve a PR number: use $1 if given, else the current branch's PR.
_resolve_pr() {
  if [ -n "${1:-}" ]; then
    echo "$1"
    return
  fi
  pr_current
}

# --- verbs: repo / auth ------------------------------------------------------

cmd_host() { _host; }
cmd_repo() { _repo; }

# Web host serving repo pages/blobs (for link allowlists), e.g. github.com or
# git.srvrs.co. Distinct from `host` (which is the backend name).
cmd_web_host() {
  case "$(_host)" in
    github) echo "github.com" ;;
    forgejo) _url_host "${FORGEJO_URL:?FORGEJO_URL not set}" ;;
  esac
}

# forge blob-base <sha> — base URL for linking a file at a commit, minus the
# trailing "/<path>#Ln". The path style differs by forge: GitHub serves blobs
# at /blob/<sha>/<path>, Forgejo/Gitea at /src/commit/<sha>/<path>. Callers
# append "/<file>#L<line>".
cmd_blob_base() {
  local sha="$1" repo
  repo="$(_repo)"
  case "$(_host)" in
    github) echo "https://github.com/${repo}/blob/${sha}" ;;
    forgejo) echo "https://$(cmd_web_host)/${repo}/src/commit/${sha}" ;;
  esac
}

cmd_default_branch() {
  case "$(_host)" in
    github) gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' ;;
    forgejo) _fj GET "repos/$(_repo)" | jq -r '.default_branch' ;;
  esac
}

cmd_auth_check() {
  case "$(_host)" in
    github) gh auth status >/dev/null 2>&1 || _die "gh not authenticated (gh auth status)" ;;
    forgejo) _fj GET "user" >/dev/null 2>&1 || _die "Forgejo token missing or invalid (\$FORGEJO_TOKEN)" ;;
  esac
}

# forge whoami — login of the authenticated user (the assignee token used to
# claim an issue). Same login regardless of which agent/host is calling.
cmd_whoami() {
  case "$(_host)" in
    github) gh api user -q '.login' ;;
    forgejo) _fj GET "user" | jq -r '.login' ;;
  esac
}

# Resolve @me to the concrete login; pass anything else through unchanged.
_resolve_user() {
  case "$1" in
    @me) cmd_whoami ;;
    *) printf '%s' "$1" ;;
  esac
}

# --- verbs: pull requests ----------------------------------------------------

pr_current() {
  case "$(_host)" in
    github)
      gh pr view --json number -q '.number' 2>/dev/null || _die "no PR for the current branch"
      ;;
    forgejo)
      local repo branch n
      repo="$(_repo)"
      branch="$(_branch)"
      n="$(_fj GET "repos/${repo}/pulls?state=open&limit=50" |
        jq -r --arg b "$branch" 'map(select(.head.ref == $b)) | .[0].number // empty')"
      [ -n "$n" ] || _die "no open PR for branch '$branch'"
      echo "$n"
      ;;
  esac
}
cmd_pr_current() { pr_current; }

# Normalised PR object. Keys: number,title,body,base,head,headSha,url,state,
# additions,deletions,changedFiles.
# NOTE: `state` is passed through verbatim, so its casing differs by provider
# (GitHub: OPEN/CLOSED/MERGED; Forgejo/Gitea: open/closed). Callers must not
# compare it case-sensitively across forges.
cmd_pr_json() {
  local n
  n="$(_resolve_pr "${1:-}")"
  _require_num "$n"
  case "$(_host)" in
    github)
      gh pr view "$n" --json number,title,url,state,body,baseRefName,headRefName,headRefOid,additions,deletions,changedFiles |
        jq '{number,title,body,url,state,
               base:.baseRefName, head:.headRefName, headSha:.headRefOid,
               additions,deletions,changedFiles}'
      ;;
    forgejo)
      _fj GET "repos/$(_repo)/pulls/${n}" |
        jq '{number:.number, title:.title, body:.body, url:.html_url,
               state:.state, base:.base.ref, head:.head.ref, headSha:.head.sha,
               additions:.additions, deletions:.deletions, changedFiles:.changed_files}'
      ;;
  esac
}

cmd_pr_diff() {
  local n
  n="$(_resolve_pr "${1:-}")"
  _require_num "$n"
  case "$(_host)" in
    github) gh pr diff "$n" ;;
    forgejo) _fj_raw "repos/$(_repo)/pulls/${n}.diff" ;;
  esac
}

# Comment bodies, one per line (used for marker/idempotency checks).
cmd_pr_comments() {
  local n
  n="$(_resolve_pr "${1:-}")"
  _require_num "$n"
  case "$(_host)" in
    github) gh pr view "$n" --json comments -q '.comments[].body' ;;
    forgejo) _fj GET "repos/$(_repo)/issues/${n}/comments" | jq -r '.[].body' ;;
  esac
}

# Changed file paths, one per line.
cmd_pr_files() {
  local n
  n="$(_resolve_pr "${1:-}")"
  _require_num "$n"
  case "$(_host)" in
    github) gh pr view "$n" --json files -q '.files[].path' ;;
    forgejo) _fj GET "repos/$(_repo)/pulls/${n}/files?limit=100" | jq -r '.[].filename' ;;
  esac
}

# forge pr-comment <n> <body>
cmd_pr_comment() {
  local n="$1" body="$2"
  _require_num "$n"
  case "$(_host)" in
    github) gh pr comment "$n" --body "$body" ;;
    forgejo)
      _fj POST "repos/$(_repo)/issues/${n}/comments" \
        "$(jq -n --arg b "$body" '{body:$b}')" >/dev/null
      ;;
  esac
}

# forge pr-edit-body <n> <body>
cmd_pr_edit_body() {
  local n="$1" body="$2"
  _require_num "$n"
  case "$(_host)" in
    github) gh pr edit "$n" --body "$body" ;;
    forgejo)
      _fj PATCH "repos/$(_repo)/pulls/${n}" \
        "$(jq -n --arg b "$body" '{body:$b}')" >/dev/null
      ;;
  esac
}

# forge pr-edit-base <n> <base>
cmd_pr_edit_base() {
  local n="$1" base="$2"
  _require_num "$n"
  case "$(_host)" in
    github) gh pr edit "$n" --base "$base" ;;
    forgejo)
      _fj PATCH "repos/$(_repo)/pulls/${n}" \
        "$(jq -n --arg b "$base" '{base:$b}')" >/dev/null
      ;;
  esac
}

# forge pr-create <title> <body> <base> <head>  — prints the PR URL.
cmd_pr_create() {
  local title="$1" body="$2" base="$3" head="$4"
  case "$(_host)" in
    github)
      gh pr create --title "$title" --body "$body" --base "$base" --head "$head"
      ;;
    forgejo)
      _fj POST "repos/$(_repo)/pulls" \
        "$(jq -n --arg t "$title" --arg b "$body" --arg base "$base" --arg head "$head" \
          '{title:$t, body:$b, base:$base, head:$head}')" |
        jq -r '.html_url'
      ;;
  esac
}

# forge pr-merge <n> [squash|merge|rebase]  (default squash)
cmd_pr_merge() {
  local n="$1" method="${2:-squash}"
  _require_num "$n"
  case "$(_host)" in
    github) gh pr merge "$n" "--${method}" ;;
    forgejo)
      _fj POST "repos/$(_repo)/pulls/${n}/merge" \
        "$(jq -n --arg d "$method" '{Do:$d}')" >/dev/null
      ;;
  esac
}

# forge pr-labels <n> <label>...  — add labels by name.
cmd_pr_labels() {
  local n="$1"
  shift
  _require_num "$n"
  [ "$#" -gt 0 ] || return 0
  case "$(_host)" in
    github)
      local args=()
      local l
      for l in "$@"; do args+=(--add-label "$l"); done
      gh pr edit "$n" "${args[@]}"
      ;;
    forgejo)
      local ids
      ids="$(_fj_label_ids "$@")"
      _fj POST "repos/$(_repo)/issues/${n}/labels" \
        "$(jq -n --argjson ids "$ids" '{labels:$ids}')" >/dev/null
      ;;
  esac
}

# --- verbs: issues -----------------------------------------------------------

# Normalised issue object: number,title,body,state,url,labels[],assignees[],
# comments (count). assignees[] is the machine-readable claim token: an agent
# reads labels and assignees in this one call to decide if an issue is free.
cmd_issue_json() {
  local n="$1"
  _require_num "$n"
  case "$(_host)" in
    github)
      gh issue view "$n" --json number,title,body,state,url,labels,assignees,comments |
        jq '{number,title,body,state,url,
               labels:[.labels[].name],
               assignees:[.assignees[].login], comments:(.comments|length)}'
      ;;
    forgejo)
      _fj GET "repos/$(_repo)/issues/${n}" |
        jq '{number:.number, title:.title, body:.body, state:.state,
               url:.html_url, labels:[.labels[].name],
               assignees:[(.assignees // [])[].login], comments:.comments}'
      ;;
  esac
}

# forge issue-list [state] [limit]  — state open|closed|all (default open).
cmd_issue_list() {
  local state="${1:-open}" limit="${2:-20}"
  # state/limit are interpolated into the Forgejo REST URL, so constrain them:
  # state to the API's allowed values, limit to digits only.
  case "$state" in
    open | closed | all) ;;
    *) _die "invalid --state '$state' (expected: open, closed, all)" ;;
  esac
  [[ "$limit" =~ ^[0-9]+$ ]] || _die "invalid --limit '$limit' (expected a number)"
  case "$(_host)" in
    github)
      gh issue list --state "$state" --limit "$limit" --json number,title,labels |
        jq 'map({number,title, labels:[.labels[].name]})'
      ;;
    forgejo)
      _fj GET "repos/$(_repo)/issues?type=issues&state=${state}&limit=${limit}" |
        jq 'map({number:.number, title:.title, labels:[.labels[].name]})'
      ;;
  esac
}

# forge issue-create <title> <body> [label]...  — prints the issue URL.
cmd_issue_create() {
  local title="$1" body="$2"
  shift 2
  case "$(_host)" in
    github)
      local args=()
      local l
      for l in "$@"; do args+=(--label "$l"); done
      gh issue create --title "$title" --body "$body" "${args[@]}"
      ;;
    forgejo)
      local labels_json='[]'
      [ "$#" -gt 0 ] && labels_json="$(_fj_label_ids "$@")"
      _fj POST "repos/$(_repo)/issues" \
        "$(jq -n --arg t "$title" --arg b "$body" --argjson l "$labels_json" \
          '{title:$t, body:$b, labels:$l}')" |
        jq -r '.html_url'
      ;;
  esac
}

# Issue comment bodies, one per line (issue-json returns only a count, so
# callers that need the actual comment text — e.g. untrusted-input scanning —
# use this). In Gitea PRs and issues share the /issues/{n}/comments endpoint.
cmd_issue_comments() {
  local n="$1"
  _require_num "$n"
  case "$(_host)" in
    github) gh issue view "$n" --json comments -q '.comments[].body' ;;
    forgejo) _fj GET "repos/$(_repo)/issues/${n}/comments" | jq -r '.[].body' ;;
  esac
}

# Issue comments as a JSON array [{id, body}], ordered by the forge's numeric,
# monotonic comment id. The lowest id is the earliest comment, so a consumer can
# resolve "who claimed first" with `sort_by(.id) | .[0]`. This MUST agree with
# the issue-side lease's winner (github-issue.sh `_lease_claim`), which sorts the
# same REST comment ids — so both compute the identical lowest-id winner.
# GitHub's REST comments endpoint yields the numeric database id (unlike
# `gh issue view --json comments`, whose GraphQL node ids are non-numeric
# strings). --paginate merges every page into one array. Forgejo's comment id is
# a numeric auto-increment. A read failure exits non-zero (no partial JSON).
cmd_issue_comments_json() {
  local n="$1"
  _require_num "$n"
  case "$(_host)" in
    github)
      # --paginate merges every page into ONE JSON array (the lease's
      # _lease_claim_comments reads it the same way), so a single `.[]` walk
      # covers all comments.
      gh api "repos/$(_repo)/issues/${n}/comments" --paginate |
        jq '[.[] | {id, body}]'
      ;;
    forgejo)
      _fj GET "repos/$(_repo)/issues/${n}/comments" |
        jq '[.[] | {id, body}]'
      ;;
  esac
}

# forge issue-comment <n> <body>
cmd_issue_comment() {
  local n="$1" body="$2"
  _require_num "$n"
  case "$(_host)" in
    github) gh issue comment "$n" --body "$body" ;;
    forgejo)
      _fj POST "repos/$(_repo)/issues/${n}/comments" \
        "$(jq -n --arg b "$body" '{body:$b}')" >/dev/null
      ;;
  esac
}

# forge issue-close <n>
cmd_issue_close() {
  local n="$1"
  _require_num "$n"
  case "$(_host)" in
    github) gh issue close "$n" ;;
    forgejo)
      _fj PATCH "repos/$(_repo)/issues/${n}" '{"state":"closed"}' >/dev/null
      ;;
  esac
}

# forge issue-assign <n> <user>...  — add assignees to the issue (@me allowed).
# The assignee is a human-visible ownership hint. GitHub's --add-assignee is
# already additive. Forgejo's PATCH replaces the whole assignee set, so a naive
# PATCH would silently wipe an existing human assignee (and blind the re-read
# claim check). We instead read the current set, refuse if a user we are NOT
# adding already holds it, and PATCH the union so no legitimate holder is lost.
cmd_issue_assign() {
  local n="$1"
  shift
  _require_num "$n"
  [ "$#" -gt 0 ] || _die "issue-assign needs at least one user"
  local users=()
  local u
  for u in "$@"; do users+=("$(_resolve_user "$u")"); done
  case "$(_host)" in
    github)
      local args=()
      for u in "${users[@]}"; do args+=(--add-assignee "$u"); done
      gh issue edit "$n" "${args[@]}" >/dev/null
      ;;
    forgejo)
      local repo users_json current foreign merged
      repo="$(_repo)"
      users_json="$(printf '%s\n' "${users[@]}" | jq -R . | jq -sc .)"
      current="$(_fj GET "repos/${repo}/issues/${n}" |
        jq -c '[((.assignees // [])[].login)]')"
      # A user already assigned who is not in the set we are adding is "foreign".
      # Refuse rather than replace: stealing an existing holder is never correct.
      foreign="$(jq -rn --argjson cur "$current" --argjson add "$users_json" \
        '($cur - $add) | .[0] // empty')"
      [ -z "$foreign" ] || _die "issue #${n} already assigned to '${foreign}'; refusing to replace"
      # Union existing + requested, deduplicated, then write the whole set back.
      merged="$(jq -cn --argjson cur "$current" --argjson add "$users_json" \
        '($cur + $add) | unique')"
      _fj PATCH "repos/${repo}/issues/${n}" \
        "$(jq -n --argjson a "$merged" '{assignees:$a}')" >/dev/null
      ;;
  esac
}

# forge issue-unassign <n> <user>...  — drop assignees, releasing the claim.
# Gitea/Forgejo has NO DELETE repos/.../issues/{n}/assignees route, so we read
# the current set, subtract the named users, and PATCH the remainder back
# (empty array = full drop). Only the named users are removed; any other
# assignee stays. The body is built with jq --argjson, never interpolation.
cmd_issue_unassign() {
  local n="$1"
  shift
  _require_num "$n"
  [ "$#" -gt 0 ] || _die "issue-unassign needs at least one user"
  local users=()
  local u
  for u in "$@"; do users+=("$(_resolve_user "$u")"); done
  case "$(_host)" in
    github)
      local args=()
      for u in "${users[@]}"; do args+=(--remove-assignee "$u"); done
      gh issue edit "$n" "${args[@]}" >/dev/null
      ;;
    forgejo)
      local repo drop_json remaining
      repo="$(_repo)"
      drop_json="$(printf '%s\n' "${users[@]}" | jq -R . | jq -sc .)"
      remaining="$(_fj GET "repos/${repo}/issues/${n}" |
        jq -c --argjson drop "$drop_json" '[((.assignees // [])[].login)] - $drop')"
      _fj PATCH "repos/${repo}/issues/${n}" \
        "$(jq -n --argjson a "$remaining" '{assignees:$a}')" >/dev/null
      ;;
  esac
}

# forge issue-labels <n> <label>...  — add labels to an issue by name.
cmd_issue_labels() {
  local n="$1"
  shift
  _require_num "$n"
  [ "$#" -gt 0 ] || return 0
  case "$(_host)" in
    github)
      local args=()
      local l
      for l in "$@"; do args+=(--add-label "$l"); done
      gh issue edit "$n" "${args[@]}" >/dev/null
      ;;
    forgejo)
      local ids
      ids="$(_fj_label_ids "$@")"
      _fj POST "repos/$(_repo)/issues/${n}/labels" \
        "$(jq -n --argjson ids "$ids" '{labels:$ids}')" >/dev/null
      ;;
  esac
}

# forge issue-unlabel <n> <label>...  — remove labels from an issue by name.
cmd_issue_unlabel() {
  local n="$1"
  shift
  _require_num "$n"
  [ "$#" -gt 0 ] || return 0
  case "$(_host)" in
    github)
      local args=()
      local l
      for l in "$@"; do args+=(--remove-label "$l"); done
      gh issue edit "$n" "${args[@]}" >/dev/null
      ;;
    forgejo)
      local ids id
      ids="$(_fj_label_ids "$@")"
      for id in $(printf '%s' "$ids" | jq -r '.[]'); do
        _fj DELETE "repos/$(_repo)/issues/${n}/labels/${id}" >/dev/null
      done
      ;;
  esac
}

# Normalised labels: [{name,description}]
cmd_label_list() {
  case "$(_host)" in
    github) gh label list --json name,description ;;
    forgejo)
      _fj GET "repos/$(_repo)/labels?limit=100" |
        jq 'map({name, description})'
      ;;
  esac
}

# --- verbs: releases / contents ---------------------------------------------

# forge release-create <tag> [--notes-from-tag | <notes>]
cmd_release_create() {
  local tag="$1" notes="${2:-}"
  if [ "$notes" = "--notes-from-tag" ]; then
    notes="$(git tag -l --format='%(contents)' "$tag")"
  fi
  case "$(_host)" in
    github)
      if [ -n "$notes" ]; then
        gh release create "$tag" --notes "$notes"
      else
        gh release create "$tag" --generate-notes
      fi
      ;;
    forgejo)
      _fj POST "repos/$(_repo)/releases" \
        "$(jq -n --arg t "$tag" --arg n "$notes" '{tag_name:$t, name:$t, body:$n}')" |
        jq -r '.html_url'
      ;;
  esac
}

# forge contents <path> [ref]  — prints decoded file content; exit 3 if absent.
cmd_contents() {
  local path="$1" ref="${2:-}"
  local out repo q
  repo="$(_repo)"
  q="repos/${repo}/contents/${path}"
  [ -n "$ref" ] && q="${q}?ref=${ref}"
  case "$(_host)" in
    github)
      out="$(gh api "$q" 2>/dev/null)" || return 3
      echo "$out" | jq -r '.content' | base64 -d
      ;;
    forgejo)
      out="$(_fj GET "$q" 2>/dev/null)" || return 3
      echo "$out" | jq -r '.content' | base64 -d
      ;;
  esac
}

# --- dispatch ----------------------------------------------------------------

usage() {
  cat >&2 <<'EOF'
forge — provider-aware git-forge helper (GitHub via gh, Forgejo via REST)

  forge host                          github | forgejo
  forge repo                          owner/name
  forge web-host                      github.com | git.srvrs.co (for link allowlists)
  forge blob-base <sha>               base URL for file links at a commit
  forge default-branch
  forge auth-check                    exit 0 if authenticated
  forge whoami                        login of the authenticated user

  forge pr-current                    PR number for the current branch
  forge pr-json      [n]              normalised PR object (default: current)
  forge pr-diff      [n]
  forge pr-comments  [n]              comment bodies, one per line
  forge pr-files     [n]              changed paths, one per line
  forge pr-comment   <n> <body>
  forge pr-edit-body <n> <body>
  forge pr-edit-base <n> <base>
  forge pr-create    <title> <body> <base> <head>   -> URL
  forge pr-merge     <n> [squash|merge|rebase]
  forge pr-labels    <n> <label>...

  forge issue-json     <n>           normalised issue object (comments = count)
  forge issue-comments <n>           issue comment bodies, one per line
  forge issue-comments-json <n>      [{id,body}] by numeric comment id (claim resolution)
  forge issue-list     [state] [limit]
  forge issue-create  <title> <body> [label]...     -> URL
  forge issue-comment <n> <body>
  forge issue-assign  <n> <user>...  set assignees (@me allowed) — claim token
  forge issue-unassign <n> <user>... drop assignees — release claim
  forge issue-labels  <n> <label>... add labels to an issue by name
  forge issue-unlabel <n> <label>... remove labels from an issue by name
  forge issue-close   <n>
  forge label-list

  forge release-create <tag> [--notes-from-tag | <notes>]
  forge contents       <path> [ref]  decoded file (exit 3 if absent)
EOF
  exit 64
}

main() {
  [ "$#" -ge 1 ] || usage
  local verb="$1"
  shift
  case "$verb" in
    host) cmd_host "$@" ;;
    repo) cmd_repo "$@" ;;
    web-host) cmd_web_host "$@" ;;
    blob-base) cmd_blob_base "$@" ;;
    default-branch) cmd_default_branch "$@" ;;
    auth-check) cmd_auth_check "$@" ;;
    whoami) cmd_whoami "$@" ;;
    pr-current) cmd_pr_current "$@" ;;
    pr-json) cmd_pr_json "$@" ;;
    pr-diff) cmd_pr_diff "$@" ;;
    pr-comments) cmd_pr_comments "$@" ;;
    pr-files) cmd_pr_files "$@" ;;
    pr-comment) cmd_pr_comment "$@" ;;
    pr-edit-body) cmd_pr_edit_body "$@" ;;
    pr-edit-base) cmd_pr_edit_base "$@" ;;
    pr-create) cmd_pr_create "$@" ;;
    pr-merge) cmd_pr_merge "$@" ;;
    pr-labels) cmd_pr_labels "$@" ;;
    issue-json) cmd_issue_json "$@" ;;
    issue-comments) cmd_issue_comments "$@" ;;
    issue-comments-json) cmd_issue_comments_json "$@" ;;
    issue-list) cmd_issue_list "$@" ;;
    issue-create) cmd_issue_create "$@" ;;
    issue-comment) cmd_issue_comment "$@" ;;
    issue-assign) cmd_issue_assign "$@" ;;
    issue-unassign) cmd_issue_unassign "$@" ;;
    issue-labels) cmd_issue_labels "$@" ;;
    issue-unlabel) cmd_issue_unlabel "$@" ;;
    issue-close) cmd_issue_close "$@" ;;
    label-list) cmd_label_list "$@" ;;
    release-create) cmd_release_create "$@" ;;
    contents) cmd_contents "$@" ;;
    -h | --help | help) usage ;;
    *) _die "unknown verb '$verb' (try: forge --help)" ;;
  esac
}

main "$@"
