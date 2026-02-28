# NOTE: set -euo pipefail and PATH are set by writeShellApplication

usage() {
  cat <<'EOF'
Usage: todoist-report [project-name] [--kong] [--json]

Generate a status report for a Todoist project.

Arguments:
  project-name   Name or partial name to filter projects (optional).
                 If omitted, an interactive picker shows all projects.

Options:
  --kong         Report all projects starting with "kong" (case-insensitive).
                 No project-name argument needed.
  --json         Output structured JSON instead of human-readable report
  --help, -h     Show this help

Environment:
  TODOIST_API_TOKEN   Todoist API token (required)

Examples:
  todoist-report                                  # pick interactively
  todoist-report "Kong"                           # filter then pick
  todoist-report "Kong" --json                    # JSON for piping
  todoist-report "Kong" --json | claude -p "Summarize this and flag blockers"
  todoist-report --kong                           # all Kong projects, human-readable
  todoist-report --kong --json | claude -p "Summarize all Kong project statuses and flag blockers"
EOF
}

JSON_MODE=false
KONG_MODE=false
PROJECT_NAME=""

for arg in "$@"; do
  case "$arg" in
    --json)
      JSON_MODE=true
      ;;
    --kong)
      KONG_MODE=true
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    -*)
      printf 'Unknown option: %s\n' "$arg" >&2
      exit 1
      ;;
    *)
      if [[ -n "$PROJECT_NAME" ]]; then
        printf 'Error: too many arguments\n' >&2
        usage >&2
        exit 1
      fi
      PROJECT_NAME="$arg"
      ;;
  esac
done

if [[ -z "$PROJECT_NAME" && "$KONG_MODE" == "false" ]]; then
  usage >&2
  exit 1
fi

if [[ -z "${TODOIST_API_TOKEN:-}" ]]; then
  printf 'Error: TODOIST_API_TOKEN is not set.\n' >&2
  printf 'Set it via shadowenv or: export TODOIST_API_TOKEN=your-token\n' >&2
  exit 1
fi

API="https://api.todoist.com/api/v1"

api_get_raw() {
  curl -fsSL \
    -H "Authorization: Bearer ${TODOIST_API_TOKEN}" \
    "${API}/${1}"
}

# Fetches all pages of a paginated endpoint and returns a single combined array.
api_get_all() {
  local endpoint="$1"
  local all_results="[]"
  local cursor=""
  local sep="?"
  local page_json
  local page_results
  local req

  if [[ "$endpoint" == *"?"* ]]; then
    sep="&"
  fi

  while true; do
    req="$endpoint"
    if [[ -n "$cursor" ]]; then
      req="${endpoint}${sep}cursor=${cursor}"
    fi

    page_json="$(api_get_raw "$req")"
    page_results="$(printf '%s' "$page_json" | jq '.results')"
    all_results="$(printf '%s' "$all_results" | jq --argjson page "$page_results" '. + $page')"
    cursor="$(printf '%s' "$page_json" | jq -r '.next_cursor // ""')"

    [[ -z "$cursor" ]] && break
  done

  printf '%s' "$all_results"
}

gum log --level info "Fetching projects..." >&2
projects_json="$(api_get_all "projects")"

if [[ "$KONG_MODE" == "true" ]]; then
  project_matches="$(
    printf '%s' "$projects_json" | jq \
      '[.[] | select(.name | ascii_downcase | startswith("kong"))]'
  )"
  match_count="$(printf '%s' "$project_matches" | jq 'length')"
  if [[ "$match_count" -eq 0 ]]; then
    gum log --level error "No projects found starting with \"kong\"" >&2
    exit 1
  fi
else
  # Exact match first (case-insensitive), then fall back to substring
  project_matches="$(
    printf '%s' "$projects_json" | jq \
      --arg name "$PROJECT_NAME" \
      '[.[] | select(.name | ascii_downcase == ($name | ascii_downcase))]'
  )"

  match_count="$(printf '%s' "$project_matches" | jq 'length')"

  # No exact match — try substring
  if [[ "$match_count" -eq 0 ]]; then
    project_matches="$(
      printf '%s' "$projects_json" | jq \
        --arg name "$PROJECT_NAME" \
        '[.[] | select(.name | ascii_downcase | contains($name | ascii_downcase))]'
    )"
    match_count="$(printf '%s' "$project_matches" | jq 'length')"
  fi

  if [[ "$match_count" -eq 0 ]]; then
    gum log --level error "No project found matching \"$PROJECT_NAME\"" >&2
    exit 1
  elif [[ "$match_count" -gt 1 ]]; then
    selected_name="$(
      printf '%s' "$project_matches" \
        | jq -r '.[].name' \
        | gum filter --header "Multiple projects match — select one:" --placeholder "type to search..."
    )"
    if [[ -z "$selected_name" ]]; then
      gum log --level error "No project selected." >&2
      exit 1
    fi
    project_matches="$(
      printf '%s' "$project_matches" \
        | jq --arg name "$selected_name" '[.[] | select(.name == $name)]'
    )"
  fi
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

SEPARATOR="$(gum style --foreground 240 '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')"

report_project() {
  local project_id="$1"
  local project_name="$2"
  local proj_work_dir="$3"

  gum log --level info "Fetching tasks and sections for \"$project_name\"..." >&2
  local tasks_json sections_json task_count generated today
  tasks_json="$(api_get_all "tasks?project_id=${project_id}")"
  sections_json="$(api_get_all "sections?project_id=${project_id}")"
  task_count="$(printf '%s' "$tasks_json" | jq 'length')"
  generated="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  today="$(date +%Y-%m-%d)"

  local task_idx=0
  gum log --level info "Fetching comments for $task_count tasks..." >&2

  while IFS= read -r task_json; do
    local task_id task_content comments_raw recent_comments latest_comment comment_count_task
    local priority priority_label section_id section_name section_order section_info

    task_id="$(printf '%s' "$task_json" | jq -r '.id')"
    task_content="$(printf '%s' "$task_json" | jq -r '.content')"
    gum log --level info "[$((task_idx + 1))/$task_count] $task_content" >&2

    if ! comments_raw="$(api_get_all "comments?task_id=${task_id}" 2>/dev/null)"; then
      comments_raw="[]"
    fi

    # Validate JSON; fall back to empty array if API returned unexpected output
    if ! printf '%s' "$comments_raw" | jq empty 2>/dev/null; then
      comments_raw="[]"
    fi

    # Last 5 comments sorted oldest → newest (for thread-style display)
    recent_comments="$(printf '%s' "$comments_raw" | jq 'sort_by(.posted_at) | .[-5:]')"
    latest_comment="$(printf '%s' "$recent_comments" | jq 'last // null')"
    comment_count_task="$(printf '%s' "$comments_raw" | jq 'length')"

    priority="$(printf '%s' "$task_json" | jq -r '.priority')"
    case "$priority" in
      4) priority_label="urgent" ;;
      3) priority_label="high" ;;
      2) priority_label="medium" ;;
      *) priority_label="normal" ;;
    esac

    section_id="$(printf '%s' "$task_json" | jq -r '.section_id // ""')"
    section_name=""
    section_order=99999
    if [[ -n "$section_id" && "$section_id" != "null" ]]; then
      section_info="$(printf '%s' "$sections_json" | jq --arg id "$section_id" '.[] | select(.id == $id)')"
      section_name="$(printf '%s' "$section_info" | jq -r '.name // ""')"
      section_order="$(printf '%s' "$section_info" | jq -r '.order // 99999')"
    fi

    printf '%s' "$task_json" | jq \
      --argjson latest_comment "$latest_comment" \
      --argjson recent_comments "$recent_comments" \
      --argjson comment_count "$comment_count_task" \
      --arg priority_label "$priority_label" \
      --arg section_name "$section_name" \
      --argjson section_order "$section_order" \
      '. + {
        priority_label: $priority_label,
        section: (if $section_name != "" then $section_name else null end),
        section_order: $section_order,
        latest_comment: $latest_comment,
        recent_comments: $recent_comments,
        comment_count: $comment_count
      }' > "${proj_work_dir}/task_${task_idx}.json"

    task_idx=$((task_idx + 1))
  done < <(printf '%s' "$tasks_json" | jq -c '.[]')

  # Combine all task files into a single array
  local all_tasks sorted_tasks
  if [[ "$task_idx" -eq 0 ]]; then
    all_tasks="[]"
  else
    # shellcheck disable=SC2086
    all_tasks="$(jq -s '.' ${proj_work_dir}/task_*.json)"
  fi

  # Sort: by section order, then priority descending within each section, then due date
  sorted_tasks="$(
    printf '%s' "$all_tasks" | jq '
      sort_by([
        (.section_order // 99999),
        (4 - .priority),
        (.due.date // "9999-12-31")
      ])
    '
  )"

  # ---------------------------------------------------------------------------
  # JSON OUTPUT MODE
  # ---------------------------------------------------------------------------
  if [[ "$JSON_MODE" == "true" ]]; then
    printf '%s' "$sorted_tasks" | jq \
      --arg project "$project_name" \
      --arg generated "$generated" \
      '{
        project: $project,
        generated: $generated,
        tasks: [.[] | {
          id: .id,
          content: .content,
          priority: .priority,
          priority_label: .priority_label,
          section: .section,
          due: (.due.date // .due.datetime // null),
          latest_comment: .latest_comment,
          recent_comments: .recent_comments,
          comment_count: .comment_count
        }]
      }'
    return 0
  fi

  # ---------------------------------------------------------------------------
  # HUMAN-READABLE OUTPUT MODE
  # ---------------------------------------------------------------------------
  local total_tasks urgent_count high_count seven_days_later due_soon_count last_activity
  total_tasks="$(printf '%s' "$sorted_tasks" | jq 'length')"
  urgent_count="$(printf '%s' "$sorted_tasks" | jq '[.[] | select(.priority == 4)] | length')"
  high_count="$(printf '%s' "$sorted_tasks" | jq '[.[] | select(.priority == 3)] | length')"
  seven_days_later="$(date -d "+7 days" +%Y-%m-%d)"
  due_soon_count="$(
    printf '%s' "$sorted_tasks" | jq \
      --arg today "$today" \
      --arg future "$seven_days_later" \
      '[.[] | select(
        .due != null and
        ((.due.date // .due.datetime // "")[0:10]) >= $today and
        ((.due.date // .due.datetime // "")[0:10]) <= $future
      )] | length'
  )"

  last_activity="$(
    printf '%s' "$sorted_tasks" | jq -r '
      [.[] | select(.latest_comment != null) | .latest_comment.posted_at]
      | sort | last // ""
    ' | cut -c1-10
  )"

  gum style --bold "Project: $project_name  |  Generated: $today"
  printf '%s\n' "$SEPARATOR"
  gum style --bold "OVERVIEW"
  printf '  %s tasks  |  %s urgent  |  %s high  |  %s due within 7 days\n' \
    "$total_tasks" "$urgent_count" "$high_count" "$due_soon_count"
  if [[ -n "$last_activity" ]]; then
    printf '  Last activity: %s\n' "$last_activity"
  fi
  printf '\n'

  print_task() {
    local task_json="$1"
    local content priority due_raw priority_prefix due_display due_date due_formatted section_name section_display comments_len

    content="$(printf '%s' "$task_json" | jq -r '.content')"
    priority="$(printf '%s' "$task_json" | jq -r '.priority')"
    due_raw="$(printf '%s' "$task_json" | jq -r '(.due.date // "")')"
    section_name="$(printf '%s' "$task_json" | jq -r '.section // ""')"

    case "$priority" in
      4) priority_prefix="$(gum style --foreground 196 --bold '[URGENT]') " ;;
      3) priority_prefix="$(gum style --foreground 208 --bold '[HIGH]') " ;;
      2) priority_prefix="$(gum style --foreground 220 '[MEDIUM]') " ;;
      *) priority_prefix="" ;;
    esac

    section_display=""
    if [[ -n "$section_name" ]]; then
      section_display=" — ${section_name}"
    fi

    due_display=""
    if [[ -n "$due_raw" ]]; then
      due_date="${due_raw:0:10}"
      due_formatted="$(date -d "$due_date" "+%b %-d")"
      due_display=" — Due: ${due_formatted}"
      if [[ "$due_date" < "$today" ]]; then
        due_display="${due_display} $(gum style --foreground 196 '⚠ OVERDUE')"
      fi
    fi

    printf '  ● %s%s%s%s\n' "$priority_prefix" "$content" "$section_display" "$due_display"

    comments_len="$(printf '%s' "$task_json" | jq '.recent_comments | length')"

    if [[ "$comments_len" -eq 0 ]]; then
      gum style --foreground 240 "    (no updates yet)"
    else
      gum style --foreground 240 "    Updates:"
      while IFS= read -r comment_json; do
        local posted_at comment_date comment_date_fmt comment_content
        posted_at="$(printf '%s' "$comment_json" | jq -r '.posted_at')"
        comment_date="${posted_at:0:10}"
        comment_date_fmt="$(date -d "$comment_date" "+%b %-d")"
        comment_content="$(printf '%s' "$comment_json" | jq -r '.content')"
        if [[ "${#comment_content}" -gt 120 ]]; then
          comment_content="${comment_content:0:117}..."
        fi
        printf '      %s %s "%s"\n' "$comment_date_fmt" "$(gum style --foreground 240 '→')" "$comment_content"
      done < <(printf '%s' "$task_json" | jq -c '.recent_comments[]')
    fi

    printf '\n'
  }

  local current_section="__unset__"
  while IFS= read -r task; do
    if [[ -n "$task" ]]; then
      task_section="$(printf '%s' "$task" | jq -r '.section // ""')"
      if [[ "$task_section" != "$current_section" ]]; then
        current_section="$task_section"
        if [[ -n "$current_section" ]]; then
          gum style --bold --underline --foreground 33 "$current_section"
        else
          gum style --bold --underline --foreground 240 "NO SECTION"
        fi
      fi
      print_task "$task"
    fi
  done < <(printf '%s' "$sorted_tasks" | jq -c '.[]')

  printf '%s\n' "$SEPARATOR"
}

# ---------------------------------------------------------------------------
# MAIN EXECUTION LOOP
# ---------------------------------------------------------------------------
proj_idx=0
while IFS= read -r proj_json; do
  pid="$(printf '%s' "$proj_json" | jq -r '.id')"
  pname="$(printf '%s' "$proj_json" | jq -r '.name')"
  proj_dir="${work_dir}/proj_${proj_idx}"
  mkdir -p "$proj_dir"

  if [[ "$JSON_MODE" == "true" ]]; then
    report_project "$pid" "$pname" "$proj_dir" > "${work_dir}/proj_${proj_idx}.json"
  else
    if [[ "$proj_idx" -gt 0 ]]; then
      printf '\n%s\n\n' "$SEPARATOR"
    fi
    report_project "$pid" "$pname" "$proj_dir"
  fi

  proj_idx=$((proj_idx + 1))
done < <(printf '%s' "$project_matches" | jq -c '.[]')

# Emit JSON output after all projects processed
if [[ "$JSON_MODE" == "true" ]]; then
  if [[ "$KONG_MODE" == "true" ]]; then
    # shellcheck disable=SC2086
    jq -s '.' ${work_dir}/proj_*.json
  else
    cat "${work_dir}/proj_0.json"
  fi
fi
