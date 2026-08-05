#!/usr/bin/env bats
# Regression test for the skill-enumeration bug found in PR #376 (issue #373):
# vendored skills (humanizer, intent-layer, walkr-author,
# walkr-tutorial-author, and the seven VibeCurb skills, see
# .claude/docs/vendored-skills.md) are symlinked into ~/.claude/skills by
# activation.nix, not plain directories. `find` without -L reports a symlink
# to a directory as -type l, not -type d, so the old `find "$skills_dir"
# -type d` silently dropped every vendored skill from the picker: installed,
# but never selectable. -L makes find dereference symlinks before typing them.
#
# Stubs fzf to dump the tab-delimited lines it was fed to a capture file and
# select nothing, so these tests observe the discovery list ($skills / the
# build_lines output) without needing real terminal interaction.

SCRIPT="${BATS_TEST_DIRNAME}/../skill-pick.bash"

setup() {
  TMP="$(mktemp -d)"
  export HOME="$TMP/home"
  SKILLS_DIR="$HOME/.claude/skills"
  mkdir -p "$SKILLS_DIR"

  # A plain repo-owned skill (rsync-copied by activation, real directory).
  mkdir -p "$SKILLS_DIR/plain-skill"
  echo "---" > "$SKILLS_DIR/plain-skill/SKILL.md"

  # A vendored skill: real content lives elsewhere, symlinked in, exactly
  # like activation.nix's `ln -snf "$src" "$claude_home/skills/$name"`.
  VENDOR_SRC="$TMP/vendor-src/some-skill"
  mkdir -p "$VENDOR_SRC"
  echo "---" > "$VENDOR_SRC/SKILL.md"
  ln -s "$VENDOR_SRC" "$SKILLS_DIR/vendored-skill"

  # A dangling symlink (upstream rename/removal after a lock bump, or a
  # half-finished activation). Must NOT appear in the picker or crash it.
  ln -s "$TMP/does-not-exist" "$SKILLS_DIR/dangling-skill"

  # Fake bin dir: real jq (needed for the settings-merge logic), stub fzf.
  FAKE_BIN="$TMP/bin"
  mkdir -p "$FAKE_BIN"
  FZF_INPUT_CAPTURE="$TMP/fzf-input.txt"
  cat > "$FAKE_BIN/fzf" <<EOF
#!/usr/bin/env bash
cat > "$FZF_INPUT_CAPTURE"
exit 0
EOF
  chmod +x "$FAKE_BIN/fzf"
  PATH="$FAKE_BIN:$PATH"

  cd "$TMP" || exit 1
}

teardown() {
  rm -rf "$TMP"
}

@test "picker discovery includes a symlinked (vendored) skill" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qP '\tvendored-skill$' "$FZF_INPUT_CAPTURE"
}

@test "picker discovery includes a plain (repo-owned) skill" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qP '\tplain-skill$' "$FZF_INPUT_CAPTURE"
}

@test "picker discovery excludes a dangling symlink" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  ! grep -qP '\tdangling-skill$' "$FZF_INPUT_CAPTURE"
}
