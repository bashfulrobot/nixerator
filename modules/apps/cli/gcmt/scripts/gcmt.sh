# NOTE: set -euo pipefail and PATH are set by writeShellApplication

# ── Colours ──────────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

info() { printf '%s▸ %s%s\n' "$CYAN" "$*" "$NC"; }
ok() { printf '%s✔ %s%s\n' "$GREEN" "$*" "$NC"; }
warn() { printf '%s⚠ %s%s\n' "$YELLOW" "$*" "$NC"; }
die() {
  printf '%s✖ %s%s\n' "$RED" "$*" "$NC" >&2
  exit 1
}

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: gcmt [--ai claude|gemini] [--push]

Interactive conventional commit tool with gum UI and AI-generated body.

  - Multi-select staged/unstaged files via fuzzy picker
  - Choose commit type (feat, fix, chore, …) with auto emoji
  - Enter scope and summary
  - AI fills the body; you review/edit before committing

Options:
  --ai <tool>   AI backend to use for body generation (default: claude)
  --push        Push to remote after committing
  -h, --help    Show this help
EOF
}

# ── Args ──────────────────────────────────────────────────────────────────────
AI_TOOL="claude"
DO_PUSH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ai)
      [[ $# -ge 2 ]] || die "--ai requires an argument (claude|gemini)"
      AI_TOOL="$2"
      shift 2
      ;;
    --push)
      DO_PUSH=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "unknown flag: $1" ;;
  esac
done

case "$AI_TOOL" in
  claude | gemini) ;;
  *) die "unsupported AI tool: $AI_TOOL (choose claude or gemini)" ;;
esac

# ── Guard ─────────────────────────────────────────────────────────────────────
git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"

# ── Type → emoji ──────────────────────────────────────────────────────────────
get_emoji() {
  case "$1" in
    feat) printf '✨' ;;
    fix) printf '🐛' ;;
    docs) printf '📝' ;;
    style) printf '🎨' ;;
    refactor) printf '♻️' ;;
    perf) printf '⚡' ;;
    test) printf '✅' ;;
    build) printf '👷' ;;
    ci) printf '💚' ;;
    chore) printf '🔧' ;;
    revert) printf '⏪' ;;
    security) printf '🔒' ;;
    deps) printf '⬆️' ;;
    *) printf '' ;;
  esac
}

# ── Step 1: file selection ─────────────────────────────────────────────────────
gum style --bold --border normal --padding "0 1" "gcmt — conventional commit"
printf '\n'

# Build display list from git status --porcelain
FILE_LIST=""
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  xy="${line:0:2}"
  raw="${line:3}"
  # Renames: "old -> new" — grab the new name
  file=$(printf '%s' "$raw" | sed 's/.*-> //')

  x="${xy:0:1}" # index
  y="${xy:1:1}" # worktree

  if [[ "$xy" == "??" ]]; then
    label="[new]     "
  elif [[ "$x" != " " && "$y" != " " ]]; then
    label="[modified]"
  elif [[ "$x" != " " ]]; then
    label="[staged]  "
  elif [[ "$y" != " " ]]; then
    label="[unstaged]"
  else
    label="[changed] "
  fi

  FILE_LIST+="${label} ${file}"$'\n'
done < <(git status --porcelain)

if [[ -z "$FILE_LIST" ]]; then
  die "nothing to commit — working tree is clean"
fi
FILE_LIST="${FILE_LIST%$'\n'}" # strip trailing newline

SELECTED=$(printf '%s' "$FILE_LIST" |
  gum choose \
    --no-limit \
    --header "Select files to include (space=toggle, enter=confirm):" \
    --cursor "▶ " \
    --selected-prefix "✓ " \
    --unselected-prefix "  ") || die "aborted"

[[ -n "$SELECTED" ]] || die "no files selected — aborted"

# Unstage everything currently in the index (keeps changes in worktree)
if ! git diff --cached --quiet; then
  git restore --staged -- . 2>/dev/null || git reset HEAD -- . 2>/dev/null
fi

# Stage only the selected files
while IFS= read -r entry; do
  [[ -z "$entry" ]] && continue
  # Strip "[label] " prefix
  file=$(printf '%s' "$entry" | sed 's/^\[[^]]*\][[:space:]]*//')
  git add -- "$file"
done <<<"$SELECTED"

git diff --cached --quiet && die "nothing staged after selection — aborted"

# ── Step 2: commit type ──────────────────────────────────────────────────────
printf '\n'
TYPE=$(gum choose \
  "feat" "fix" "docs" "style" "refactor" \
  "perf" "test" "build" "ci" "chore" \
  "revert" "security" "deps" \
  --header "Select commit type:") || die "aborted"

[[ -n "$TYPE" ]] || die "no type selected — aborted"
EMOJI=$(get_emoji "$TYPE")

# ── Step 3: scope ─────────────────────────────────────────────────────────────
printf '\n'
SCOPE=$(gum input \
  --placeholder "lowercase kebab-case, e.g. auth, api, git" \
  --header "Scope (required):") || die "aborted"

[[ -n "$SCOPE" ]] || die "scope is required — aborted"

# ── Step 4: summary ───────────────────────────────────────────────────────────
printf '\n'
SUMMARY=$(gum input \
  --prompt "$TYPE($SCOPE): $EMOJI " \
  --placeholder "imperative, lowercase, no period" \
  --char-limit 72 \
  --header "Commit summary:") || die "aborted"

[[ -n "$SUMMARY" ]] || die "summary is required — aborted"

SUBJECT="$TYPE($SCOPE): $EMOJI $SUMMARY"

if [[ ${#SUBJECT} -gt 72 ]]; then
  warn "subject is ${#SUBJECT} chars — recommended max is 72"
fi

# ── Step 5: AI body ───────────────────────────────────────────────────────────
DIFF=$(git diff --cached)

AI_PROMPT="You are writing the body of a git commit message.

Commit summary: $SUBJECT

Based on the following git diff, write 3-5 concise bullet points.
Rules:
- Each line starts with '- '
- Imperative mood
- Max 72 chars per line
- Explain WHAT changed and WHY, not HOW
- Do NOT repeat the summary line
- Output ONLY the bullet points, nothing else

Git diff:
$DIFF"

BODY=""
if [[ "$AI_TOOL" == "gemini" ]]; then
  if command -v gemini >/dev/null 2>&1; then
    info "Generating commit body with gemini..."
    BODY=$(printf '%s' "$AI_PROMPT" | gemini -p "Write the commit body bullet points." 2>/dev/null) || BODY=""
  else
    warn "gemini not found — falling back to claude"
    AI_TOOL="claude"
  fi
fi

if [[ "$AI_TOOL" == "claude" && -z "$BODY" ]]; then
  if command -v claude >/dev/null 2>&1; then
    info "Generating commit body with claude..."
    BODY=$(printf '%s' "$AI_PROMPT" | claude -p "Write the commit body bullet points." 2>/dev/null) || BODY=""
  else
    warn "claude not found — skipping body generation"
  fi
fi

# ── Step 6: review / edit body ───────────────────────────────────────────────
printf '\n'
BODY=$(gum write \
  --placeholder "Commit body (bullet points). Leave empty to omit." \
  --value="$BODY" \
  --header "Review/edit body (ctrl+d to finish, esc to clear):" \
  --width 80 \
  --height 10) || BODY=""

# ── Step 7: preview ──────────────────────────────────────────────────────────
printf '\n'
gum style --bold --underline "─── Commit Preview ───"
printf '\n'
gum style --foreground 2 --bold "$SUBJECT"
if [[ -n "$BODY" ]]; then
  printf '\n'
  printf '%s\n' "$BODY"
fi
printf '\n'

# ── Step 8: commit ────────────────────────────────────────────────────────────
if [[ -n "$BODY" ]]; then
  git commit -S -m "$SUBJECT" -m "$BODY"
else
  git commit -S -m "$SUBJECT"
fi

printf '\n'
ok "committed: $SUBJECT"

# ── Step 9: push (optional) ───────────────────────────────────────────────────
if [[ "$DO_PUSH" -eq 1 ]]; then
  info "Pushing to remote..."
  git push
  ok "pushed"
fi
