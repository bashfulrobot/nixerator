#!/usr/bin/env bash
# Tests for polish-editor.sh: the Ctrl+G editor wrapper. Runs the real script
# against a stub editor and a stub `claude`, with the "terminal" replaced by
# files, so nothing touches a live session. Needs jq, a timeout binary, git and
# diff on PATH. Run directly: bash polish-editor.test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
check() { # name want got
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
    pass=$((pass + 1))
  else
    echo "FAIL: $1 (want=[$2] got=[$3])"
    fail=$((fail + 1))
  fi
}

# GNU `timeout`, or coreutils' `gtimeout` where timeout is not on PATH.
timeout_bin=$(command -v timeout || command -v gtimeout || true)

# Stub editor: replaces the file with $STUB_EDIT_TEXT, as if the user typed it.
cat >"$tmp/editor" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$STUB_EDIT_TEXT" >"$1"
EOF

# Stub claude: honours the per-run markers in the prompt and "polishes" by
# upper-casing whatever follows "Text to rewrite:". STUB_CLAUDE_MODE=fail makes
# it exit non-zero.
cat >"$tmp/claude" <<'EOF'
#!/usr/bin/env bash
[ "${STUB_CLAUDE_MODE:-}" = "fail" ] && { echo "boom" >&2; exit 3; }
prompt=$(cat)
b=$(printf '%s' "$prompt" | grep -o '<<TEXTPOLISH:[0-9a-f]*:BEGIN>>' | head -1)
e=$(printf '%s' "$prompt" | grep -o '<<TEXTPOLISH:[0-9a-f]*:END>>' | head -1)
body=$(printf '%s\n' "$prompt" | awk 'f{print} /^Text to rewrite:/{f=1}' | sed '/./,$!d' | tr 'a-z' 'A-Z')
jq -n --arg r "$(printf '%s\n%s\n%s' "$b" "$body" "$e")" \
  '{is_error:false, subtype:"success", result:$r}'
EOF
chmod +x "$tmp/editor" "$tmp/claude"
printf 'rules\n' >"$tmp/rules.md"

# Tool and path overrides the Nix build normally substitutes.
export TEXT_POLISH_CORE="$here/text-polish-core.sh"
export TEXT_POLISH_JQ="jq"
export TEXT_POLISH_TIMEOUT="$timeout_bin"
export TEXT_POLISH_OD="od"
export TEXT_POLISH_TR="tr"
export TEXT_POLISH_GIT="git"
export TEXT_POLISH_DIFF="diff"
export TEXT_POLISH_DEFAULT_EDITOR="$tmp/editor"
export TEXT_POLISH_CLAUDE="$tmp/claude"
export TEXT_POLISH_RULES="$tmp/rules.md"

# run_case <answer-chars> <edit-text> -> file contents after the run
run_case() {
  local file="$tmp/prompt.txt"
  printf 'seed\n' >"$file"
  printf '%s' "$1" >"$tmp/tty_in"
  : >"$tmp/tty_out"
  STUB_EDIT_TEXT="$2" POLISH_EDITOR="$tmp/editor" \
    PE_TTY_IN="$tmp/tty_in" PE_TTY_OUT="$tmp/tty_out" \
    bash "$here/polish-editor.sh" "$file" >/dev/null 2>&1
  echo "$?" >"$tmp/rc" # run_case runs in a command substitution, so a variable would be lost
  cat "$file"
}

check "yes writes the polished text" "HELLO THERE" "$(run_case y 'hello there')"
check "bare enter counts as yes" "HELLO THERE" "$(run_case $'\n' 'hello there')"
check "no keeps the original text" "hello there" "$(run_case n 'hello there')"
check "unknown key keeps the original text" "hello there" "$(run_case x 'hello there')"

# Edit rewrites the file with the polished text, then reopens the editor, which
# here overwrites it again with the stub text.
check "edit reopens the editor" "hello there" "$(run_case e 'hello there')"

check "blank file is left alone" "" "$(run_case y '')"

# A credential-shaped string must never reach claude: the file stays as typed.
check "credential-shaped text is not sent" "key AKIAABCDEFGHIJKLMNOP" \
  "$(run_case y 'key AKIAABCDEFGHIJKLMNOP')"

# claude failing must cost nothing and exit 0.
out=$(STUB_CLAUDE_MODE=fail run_case y 'hello there')
check "claude failure keeps the text" "hello there" "$out"
check "claude failure exits 0" "0" "$(cat "$tmp/rc")"

# No terminal to ask on: leave the text alone, exit 0.
file="$tmp/prompt.txt"
printf 'seed\n' >"$file"
STUB_EDIT_TEXT="hello there" POLISH_EDITOR="$tmp/editor" \
  PE_TTY_IN="$tmp/does-not-exist" PE_TTY_OUT="$tmp/tty_out" \
  bash "$here/polish-editor.sh" "$file" >/dev/null 2>&1
check "no terminal keeps the text" "hello there" "$(cat "$file")"

# The wrapper must not call itself as the real editor: a POLISH_EDITOR of
# polish-editor falls back to the default editor (the stub), so the edit lands.
printf 'seed\n' >"$file"
printf 'n' >"$tmp/tty_in"
STUB_EDIT_TEXT="typed by default editor" POLISH_EDITOR=polish-editor \
  PE_TTY_IN="$tmp/tty_in" PE_TTY_OUT="$tmp/tty_out" \
  bash "$here/polish-editor.sh" "$file" >/dev/null 2>&1
check "self-reference falls back to the default editor" "typed by default editor" "$(cat "$file")"

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
