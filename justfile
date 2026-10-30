# NixOS Configuration Management
# https://github.com/casey/just

# === Settings ===
set dotenv-load := true
set ignore-comments := true
set fallback := true
set shell := ["bash", "-euo", "pipefail", "-c"]

mod ref 'extras/ref.just'
mod setup 'extras/setup.just'

# === Variables ===
hostname := `hostname`
host_flake := ".#" + hostname
timestamp := `date +%Y-%m-%d_%H-%M-%S`

# === Private Helpers ===
# Shared by the rebuild/upgrade/bump recipes below. `[private]` hides these
# from `just --list`.

# Print a warning-count summary for a log, or a success message if there are none
[private]
warn-summary log warn_msg success_msg:
    #!/usr/bin/env bash
    set -uo pipefail
    warnings=$(grep -c -E -i 'warning:' {{log}} 2>/dev/null || true)
    if [[ "$warnings" -gt 0 ]]; then
        gum style --foreground 220 "{{warn_msg}} with $warnings warning(s)"
        if gum confirm "View warnings in log?"; then
            bat --paging=always {{log}}
        fi
    else
        gum style --foreground 82 "{{success_msg}}"
    fi

# Rewrite a failed build log in place: filtered errors/warnings up top, full log below
[private]
filter-log log:
    #!/usr/bin/env bash
    set -uo pipefail
    filtered=$(grep -E -i '(^error|error:|warning:|trace:|fatal|failed to)' {{log}} | head -80)
    {
        echo "=== FILTERED ERRORS/WARNINGS ==="
        echo "$filtered"
        echo ""
        echo "=== FULL BUILD LOG ==="
        cat {{log}}
    } > {{log}}.tmp
    mv {{log}}.tmp {{log}}

# === Help ===
#
# Listing convention: `just --list` renders the LAST line of the `#` block
# above a recipe, so a recipe whose comment ends in a long explanation shows a
# mid-sentence fragment as its description. Where the comment is more than one
# line, give the recipe an explicit `[doc('...')]` attribute with a one-line
# summary; the full `#` block stays as the in-file explanation. Single-line
# comments need no attribute. Every public recipe also carries a `[group()]`
# so the listing stays navigable.

# Show available recipes
[group('dev')]
default:
    @just --list --unsorted

# Open the visual repo tour (extras/docs/index.html) in a browser
[group('dev')]
docs:
    #!/usr/bin/env bash
    if command -v xdg-open >/dev/null 2>&1; then xdg-open extras/docs/index.html
    else open extras/docs/index.html; fi

# === Core Recipes ===
# Production rebuild of the current host
[group('rebuild')]
rebuild:
    #!/usr/bin/env bash
    set -uo pipefail
    just secrets-nudge
    just pre-rebuild interactive
    log="{{rebuild_log}}"
    rc=0
    gum spin --spinner dot --title "Rebuilding NixOS configuration..." \
        -- bash -c 'sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild switch --impure --flake {{host_flake}} &> "'"$log"'"' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        just warn-summary "$log" "Rebuild succeeded" "Rebuild succeeded"
        just post-rebuild interactive

        # Run package update check in background, show results when done
        echo ""
        bash extras/scripts/check-pkg-updates.bash \
            || gum style --foreground 214 "Package update check failed (exit $?) -- see above"
        echo ""
        bash extras/scripts/check-security-alerts.bash \
            || gum style --foreground 214 "Security alert check failed (exit $?) -- see above"
    else
        gum style --foreground 196 "Rebuild FAILED (exit $rc)"
        bat --paging=always "$log"
        exit "$rc"
    fi

# Build (not switch) an arbitrary host's system closure to verify it evaluates
# and compiles. Works from any host and never activates. Use to validate a new
# host config before installing it on the target machine.
#
#   just build-host srv
[doc('Build (not switch) another host to check it still evaluates')]
[group('rebuild')]
build-host host:
    nixos-rebuild build --impure --flake ".#{{host}}"

# Test a local hyprflake checkout against the current host.
#
# Rebuilds the current host but overrides the `hyprflake` flake input to point
# at a local working tree (default: ~/git/hyprflake) so changes can be tried
# without committing/pushing hyprflake or bumping flake.lock. Pass an alternate
# path to test a different checkout/worktree:
#
#   just hyprflake-test
#   just hyprflake-test /home/dustin/git/.worktrees/hyprflake-feature
#
# Uses {{host_flake}} so it targets whichever host it runs on, like `rebuild`.
[doc('Rebuild the current host against a local hyprflake checkout')]
[group('rebuild')]
hyprflake-test path="/home/dustin/git/hyprflake":
    #!/usr/bin/env bash
    set -uo pipefail
    if [[ ! -d "{{path}}" ]]; then
        gum style --foreground 196 "hyprflake path not found: {{path}}"
        exit 1
    fi
    just secrets-nudge
    # This performs a real `switch`, so it needs the same pre-rebuild capture
    # every other switch recipe runs. Without it, any live edit to a
    # Nix-managed file since the last rebuild is silently lost at activation.
    just pre-rebuild interactive
    log="{{rebuild_log}}"
    rc=0
    gum spin --spinner dot --title "Rebuilding with local hyprflake ({{path}})..." \
        -- bash -c 'sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild switch --impure --flake {{host_flake}} --override-input hyprflake path:{{path}} &> "'"$log"'"' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        just warn-summary "$log" "Rebuild succeeded" "Rebuild succeeded (local hyprflake override active)"
    else
        gum style --foreground 196 "Rebuild FAILED (exit $rc)"
        bat --paging=always "$log"
        exit "$rc"
    fi

# Full system upgrade
[group('rebuild')]
upgrade:
    #!/usr/bin/env bash
    set -uo pipefail
    just secrets-nudge
    just pre-rebuild interactive
    log="{{upgrade_log}}"
    cp flake.lock flake.lock-backup-{{timestamp}}
    # Keep only the 5 newest lock backups.
    ls -1t flake.lock-backup-* 2>/dev/null | tail -n +6 | xargs -r rm -f
    rc=0
    gum spin --spinner dot --title "Updating flake inputs..." \
        -- bash -c 'nix flake update &> "'"$log"'"' || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        gum style --foreground 196 "Flake update FAILED (exit $rc)"
        bat --paging=always "$log"
        exit "$rc"
    fi
    gum style --foreground 82 "Flake inputs updated"
    # claude-skills (dk/kong-cs/gitops) isn't a flake input -- it's a
    # commit-SHA pin in cfg/plugin-config.nix, so `nix flake update` above
    # never touches it. Bump it the same way, right before the rebuild picks
    # up whatever's currently pinned.
    gum spin --spinner dot --title "Updating claude-skills marketplace pin..." \
        -- bash -c 'bash modules/apps/cli/claude-code/cfg/scripts/bump-plugin-marketplace-sha.sh claude-skills bashfulrobot/claude-skills main &>> "'"$log"'"' || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        gum style --foreground 196 "claude-skills pin bump FAILED (exit $rc)"
        bat --paging=always "$log"
        exit "$rc"
    fi
    gum style --foreground 82 "claude-skills pin up to date"
    gum spin --spinner dot --title "Rebuilding with upgrades..." \
        -- bash -c 'sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild switch --impure --upgrade --flake {{host_flake}} &>> "'"$log"'"' || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        gum style --foreground 196 "Rebuild FAILED (exit $rc)"
        bat --paging=always "$log"
        exit "$rc"
    fi
    gum style --foreground 82 "System rebuilt"
    gum spin --spinner dot --title "Setting up voxtype..." \
        -- bash -c 'just ref::voxtype-setup &>> "'"$log"'"' || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        gum style --foreground 196 "Voxtype setup FAILED (exit $rc)"
        bat --paging=always "$log"
        exit "$rc"
    fi
    gum style --foreground 82 "Voxtype configured"
    just warn-summary "$log" "Upgrade completed" "Upgrade complete"
    just commit-lock "chore(flake): update flake lock" interactive
    just commit-plugin-config "chore(claude-code): bump claude-skills marketplace pin" interactive
    just post-rebuild interactive

    # Run package update check after successful upgrade
    echo ""
    bash extras/scripts/check-pkg-updates.bash \
        || gum style --foreground 214 "Package update check failed (exit $?) -- see above"
    echo ""
    bash extras/scripts/check-security-alerts.bash \
        || gum style --foreground 214 "Security alert check failed (exit $?) -- see above"

# Update a specific flake input
[group('bump')]
update input:
    @echo "Updating {{input}}..."
    @nix flake update {{input}}

# Bump the claude-skills marketplace pin (dk/kong-cs/gitops) to its current
# GitHub HEAD and refresh the claude-stack snapshot at that sha, without a full `just upgrade`. Not a flake input -- see
# cfg/plugin-config.nix's selfPins (plus the cfg/claude-stack snapshot) -- so `just update claude-skills`
# doesn't reach it; this is that recipe's equivalent for this one pin.
# Doesn't commit or rebuild on its own: review the diff, then `just rebuild`
# (or fold it into your next `just upgrade` / `just quiet-upgrade`, which run
# this automatically).
[doc('Bump the claude-skills marketplace pin to its current GitHub HEAD')]
[group('bump')]
bump-claude-skills:
    bash modules/apps/cli/claude-code/cfg/scripts/bump-plugin-marketplace-sha.sh claude-skills bashfulrobot/claude-skills main

# Ship a merged claude-skills change to the NixOS hosts in one command: bump the
# pin and claude-stack snapshot on a branch, open a signed PR, ask once, then
# squash-merge it and rebuild qbert and srv. `what` goes in the commit title,
# e.g. `just ship-claude-skills "dk 3.3.6, git-cleanup fixes"`. `sha` defaults to
# claude-skills `main` HEAD; pass a 40-hex sha to pin an older merge.
#
# Run it from the primary checkout on a clean, current `main`: the PR merge
# needs `main` checked out, which a linked worktree cannot do. The merge and the
# rebuilds only run after you answer yes at the prompt. Like `bump-hyprflake`
# this commits and pushes by design. The Mac is not reached from here: the last
# lines print its two commands.
[doc('Bump the claude-skills pin via PR, merge, then rebuild qbert and srv')]
[group('bump')]
ship-claude-skills what sha="main":
    #!/usr/bin/env bash
    set -euo pipefail
    die() { echo "ship-claude-skills: $*" >&2; exit 1; }
    [[ "$(git rev-parse --git-dir)" == "$(git rev-parse --git-common-dir)" ]] \
        || die "run from the primary checkout, not a linked worktree"
    [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || die "switch to main first"
    git diff --quiet && git diff --cached --quiet || die "working tree is not clean"
    git pull --ff-only
    if [[ "{{sha}}" =~ ^[0-9a-f]{40}$ ]]; then
        full="{{sha}}"
    else
        full="$(git ls-remote https://github.com/bashfulrobot/claude-skills.git "refs/heads/{{sha}}" | awk '{print $1}')"
    fi
    [[ -n "$full" ]] || die "could not resolve claude-skills@{{sha}}"
    short="${full:0:7}"
    branch="chore/bump-claude-skills-${short}"
    msg="chore(claude-code): bump claude-skills pin to ${short} ({{what}})"
    cfg="modules/apps/cli/claude-code/cfg"
    git switch -c "$branch"
    bash "$cfg/scripts/bump-plugin-marketplace-sha.sh" claude-skills bashfulrobot/claude-skills "$full"
    if git diff --quiet -- "$cfg/plugin-config.nix" "$cfg/claude-stack"; then
        git switch main
        git branch -D "$branch"
        die "pin is already at ${short}, nothing to ship"
    fi
    git add -- "$cfg/plugin-config.nix" "$cfg/claude-stack"
    git commit -qS -m "$msg"
    git push -u origin HEAD
    pr="$(gh pr create --base main --title "$msg" --body "Pin bump from just ship-claude-skills.")"
    echo "PR: $pr"
    if ! gum confirm "Merge the PR, then rebuild qbert and srv?"; then
        echo "Stopped before the merge. Branch $branch stays checked out."
        exit 0
    fi
    gh pr merge "$pr" --squash --delete-branch
    git switch main
    git pull --ff-only
    just quiet-rebuild
    just build-host srv
    just remote-rebuild srv
    echo "qbert and srv are on ${short}. Mac, run:"
    echo "  git -C ~/git/donkeykong pull --ff-only"
    echo "  cd ~/git/donkeykong && ./claude-plugins.sh --upgrade"

# Remove linked worktrees under .claude/worktrees whose PR is merged, and delete
# their local branch. Dry run by default; `just prune-worktrees --yes` removes.
# Run it from the primary checkout: a session cannot remove its own worktree.
[doc('Remove worktrees whose PR is merged (dry run; pass --yes to remove)')]
[group('dev')]
prune-worktrees *args:
    bash extras/scripts/prune-worktrees.bash {{args}}

# Run the text-polish suites (safety filters + Ctrl+G editor wrapper)
[group('test')]
test-text-polish:
    nix shell nixpkgs#jq nixpkgs#coreutils nixpkgs#gnugrep nixpkgs#gnused nixpkgs#gawk --command bash -c 'bash modules/apps/cli/text-polish/scripts/text-polish.test.sh && bash modules/apps/cli/text-polish/scripts/polish-editor.test.sh'

# Run skill-cache unit tests
[group('test')]
test-skill-cache:
    nix shell nixpkgs#bats nixpkgs#jq --command bats modules/apps/cli/skill-cache/tests/

# Run render-secrets unit tests (Forgejo tea-config generation)
[group('test')]
test-render-secrets:
    nix shell nixpkgs#bats nixpkgs#jq nixpkgs#gawk nixpkgs#gnugrep nixpkgs#coreutils --command bats modules/apps/cli/render-secrets/tests/

# Run the claude-code PreToolUse guard-hook regression tests (secret-leak +
# primary-tree-write) plus the capture-sync settings suite in the same dir. git
# drives the primary-vs-worktree detection, coreutils provides sort/cut for the
# cwd-replay resolver and comm/stat for the installed-plugins filter, gnused
# provides the @HOME_DIR@ substitution that filter runs behind, and python3 runs
# the capture-sync reconcile tests.
#
# This sweeps the whole tests/ dir, so it also covers capture-sync-settings.bats
# (the old `test-capture-sync` recipe ran only that one file and was a strict
# subset of this, so it was removed).
[doc('Run the claude-code guard-hook + capture-sync test suites')]
[group('test')]
test-secret-guard:
    nix shell nixpkgs#bats nixpkgs#jq nixpkgs#gnugrep nixpkgs#gnused nixpkgs#git nixpkgs#coreutils nixpkgs#python3 --command bats modules/apps/cli/claude-code/cfg/scripts/tests/

# Run worktree-flow unit tests (github-issue setup branch preflight)
[group('test')]
test-worktree-flow:
    nix shell nixpkgs#bats nixpkgs#jq nixpkgs#git --command bats modules/apps/cli/worktree-flow/tests/

# Garbage collection (default: 5 days)
[group('gc')]
clean days="5":
    @echo "Cleaning packages older than {{days}} days..."
    @sudo nix-collect-garbage --delete-older-than {{days}}d

# Nuclear garbage collection — maximum cleanup
[group('gc')]
gc-nuclear:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "NUCLEAR GARBAGE COLLECTION"
    echo "================================"
    echo "Deleting old system generations..."
    sudo nix-env --delete-generations old --profile /nix/var/nix/profiles/system
    echo ""
    echo "Deleting old boot generations..."
    sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
    echo ""
    echo "Running full garbage collection..."
    sudo nix-collect-garbage -d
    echo ""
    echo "Clearing nix evaluation cache..."
    rm -rf ~/.cache/nix
    echo ""
    echo "Optimizing nix store (this may take a while)..."
    nix-store --optimize
    echo ""
    echo "Nuclear cleanup complete!"
    echo "Disk space reclaimed:"
    df -h / | tail -1

# List system generations (with current marker)
[group('gc')]
generations:
    @sudo nix-env --profile /nix/var/nix/profiles/system --list-generations

# Roll back to a previous system generation. No arg = one step back
# (`nixos-rebuild --rollback`). With arg = jump to that specific gen
# (e.g. `just rollback 721`). Asks for confirmation before switching
# because this is destructive to the current generation pointer.
[doc('Roll back to a previous system generation (no arg = one step back)')]
[group('gc')]
rollback gen="":
    #!/usr/bin/env bash
    set -uo pipefail
    sudo nix-env --profile /nix/var/nix/profiles/system --list-generations | tail -8
    echo ""
    target="{{gen}}"
    if [[ -z "$target" ]]; then
        prompt="Roll back ONE generation (sudo nixos-rebuild --rollback switch)?"
    else
        if [[ ! -L "/nix/var/nix/profiles/system-${target}-link" ]]; then
            echo "Generation ${target} not found at /nix/var/nix/profiles/system-${target}-link" >&2
            exit 1
        fi
        prompt="Switch to generation ${target}?"
    fi
    if ! gum confirm "$prompt"; then
        echo "Cancelled."
        exit 0
    fi
    if [[ -z "$target" ]]; then
        sudo nixos-rebuild --rollback switch
    else
        sudo "/nix/var/nix/profiles/system-${target}-link/bin/switch-to-configuration" switch
    fi
    echo ""
    echo "Active generation now:"
    sudo nix-env --profile /nix/var/nix/profiles/system --list-generations | grep "(current)"

# Check code health with deadnix and statix
[group('dev')]
health:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running code health checks..."
    echo ""
    echo "Checking for unused code with deadnix..."
    deadnix --fail .
    echo ""
    echo "Running statix linter..."
    fd -e nix --hidden --no-ignore --follow . -x statix check {}
    echo ""
    echo "Code health check complete"

# Format all nix files
[group('dev')]
fmt:
    @echo "Formatting nix files..."
    @nix fmt

# Auto-fix lint, dead code, and shell/fish formatting (replaces the old CI autofix job)
[group('dev')]
fix:
    #!/usr/bin/env bash
    set -euo pipefail
    # Tracked files only: `find .` would walk .claude/worktrees and ignored paths.
    # `--` and the ./ prefix stop a filename starting with `-` being read as a flag.
    git ls-files -z -- '*.nix' ':!:secrets' | xargs -0 -r nix fmt --
    git ls-files -z -- '*.nix' ':!:secrets' | xargs -0 -r -I{} statix fix ./{}
    git ls-files -z -- '*.nix' ':!:secrets' | xargs -0 -r deadnix --edit --
    git ls-files -z -- '*.sh' ':!:secrets' | xargs -0 -r shfmt -w -i 2 -ci --
    git ls-files -z -- '*.fish' ':!:secrets' \
      | xargs -0 -r fish -c 'for f in $argv; fish_indent -w "$f"; end'

# Install repo git hooks (sets core.hooksPath to .githooks for this clone)
#
# The pre-commit hook auto-formats staged .nix files via `nix fmt` so no
# commit can introduce formatting drift, regardless of editor/agent/human.
# Run once per clone.
[doc('Install repo git hooks (points core.hooksPath at .githooks)')]
[group('dev')]
setup-hooks:
    @git config core.hooksPath .githooks
    @echo "git hooks installed: core.hooksPath -> .githooks"

# Update manually-installed Claude skills from GitHub
#
# Applies skillfish-tracked updates and reports what changed via
# claude-skill-updates (which also fires a desktop notify-send on
# workstation hosts). Skills authored in this repo under config/skills/
# are managed by claude-capture and need no separate update step.
#
# Deliberately does NOT bump the flake-pinned upstream skills
# (humanizer-skill, crafter-station-skills, walkr, vibecurb-skills -- the
# last one is rev-pinned in its flake.nix url rather than tracking a branch,
# so a bare `nix flake update` doesn't move it anyway; see
# .claude/docs/vendored-skills.md). This recipe runs from
# post-rebuild, i.e. AFTER `nixos-rebuild switch`, and those skills resolve
# their store paths from flake.lock at activation time -- so a lock bump
# landing here can never reach the generation that just activated. It would
# be one full rebuild late by construction, and it leaves flake.lock dirty
# with nothing in rebuild/quiet-rebuild to commit it (commit_captures only
# covers the claude-code config and dank-profiles pathspecs, and
# quiet-rebuild's `trap git restore --staged .` unstages the rest). It also
# re-dirtied the lock that bump-upsight/bump-hyprflake had just committed.
# `just upgrade` / `just quiet-upgrade` run a bare `nix flake update` before
# the rebuild and commit the lock afterwards -- that is the correct home for
# the bump, and it sweeps every vendored-skill input. Don't re-add it here.
#
# Also does NOT cover the claude-skills marketplace (dk@claude-skills /
# kong-cs@claude-skills / gitops@claude-skills) added 2026-09-08: that one is
# pinned by commit SHA in cfg/plugin-config.nix, not a flake input, so
# neither this recipe nor a `nix flake update` moves it. Unlike the other
# SHA-pinned marketplaceSources entries, `just upgrade` / `just
# quiet-upgrade` DO bump this one automatically now (see
# bump-plugin-marketplace-sha.sh) -- it's this user's own repo, not a
# third-party one that needs a manual re-read before every bump. Run `just
# bump-claude-skills` to bump it on its own, outside a full upgrade. Most of
# what used to be captured/updated here as loose config/skills/ content now
# lives there instead -- see the retirement note atop cfg/skill-defaults.nix.
[doc('Update manually-installed Claude skills (also runs from post-rebuild)')]
[group('dev')]
update-skills:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v claude-skill-updates >/dev/null 2>&1; then
        claude-skill-updates || echo "skillfish update failed (non-fatal)"
    fi
    echo "Skills updated"

# Ad-hoc capture of live ~/.claude and DMS (dank) state into the repo.
#
# Auto-capture during rebuild is gated to qbert (the designated source of
# truth) so non-canonical hosts don't regress the repo. Use this recipe to
# manually surface a new skill/agent/setting or DMS GUI change installed on any
# other host -- review the resulting diff and commit only the
# bits that should propagate. DMS settings land in dank-profiles/<group>.json.
#
# When run off qbert this is a DRY-RUN by default: capture-sync still
# computes the three-way diff and prints what would change, but does not
# write to the repo or to the snapshot. Set JUST_CAPTURE_FORCE=1 to
# actually apply on a non-canonical host (uncommon, and the right thing
# to do if you've just installed something new on that host and want
# to commit it from there).
[doc('Ad-hoc capture of live ~/.claude and DMS (dank) state into the repo')]
[group('capture')]
capture:
    #!/usr/bin/env bash
    set -uo pipefail
    # DMS (dank) is host-agnostic: any workstation may capture its DMS settings
    # into the shared dank-profiles/<group>.json, so it ALWAYS applies here --
    # it is not gated to qbert like the Claude Code capture below. Review the
    # resulting dank-profiles/ diff and commit only deliberate changes (a shared
    # full-file profile means any per-host DMS divergence shows up as a diff).
    if command -v dank-capture >/dev/null 2>&1 && [[ -e "$HOME/.config/DankMaterialShell/settings.json" ]]; then
        echo "Capturing DMS (dank) settings..."
        dank-capture || echo "DMS capture failed (non-fatal)"
        echo ""
    fi
    if [[ "$(hostname)" != "qbert" && "${JUST_CAPTURE_FORCE:-0}" != "1" ]]; then
        echo "just capture: Claude Code capture is gated to qbert; on $(hostname) it runs in DRY-RUN mode (DMS was captured above)."
        echo "  To also apply it here, re-run with JUST_CAPTURE_FORCE=1 just capture."
        echo ""
        # capture-sync respects --dry-run. Anchor paths on
        # justfile_directory() rather than $(pwd) so the recipe is safe
        # to invoke from any working directory.
        config_dir="{{justfile_directory()}}/modules/apps/cli/claude-code/config"
        sync_output=$(python3 "{{justfile_directory()}}/modules/apps/cli/claude-code/cfg/scripts/capture-sync.py" \
            --state-file "$config_dir/.capture-state.json" \
            --home-root "$HOME/.claude" \
            --repo-root "$config_dir" \
            --section all \
            --dry-run)
        echo "$sync_output" | jq -r '.actions[].action' | sort | uniq -c | awk '{printf "  %-12s: %s\n", $2, $1}'
        conflicts=$(echo "$sync_output" | jq -r '.conflicts | length')
        if [[ "$conflicts" -gt 0 ]]; then
            echo "  conflicts   : $conflicts"
        fi
        echo ""
        echo "Review DMS capture with: git diff dank-profiles"
        exit 0
    fi
    echo "Capturing Claude Code config..."
    fish -c 'claude-capture' || echo "Claude capture failed (non-fatal)"
    echo ""
    echo "Review with: git status && git diff modules/apps/cli/claude-code dank-profiles"

# Resolve a capture-sync conflict by picking which side wins.
# Usage: just capture-resolve skills/gsuite-edit/SKILL.md --home
#        just capture-resolve agents/foo.md --repo
# Updates the snapshot in .capture-state.json so the next `just qr` is a
# no-op for this file. Stage the resulting change in git as usual.
#
# Both args are passed through fish as separate $argv elements (not
# concatenated into a fish -c command string) so attacker-controlled
# characters in a filename can't inject shell syntax even if the
# resulting conflict line ever surfaces such a name to the user.
[doc('Resolve a capture-sync conflict by picking which side wins')]
[group('capture')]
capture-resolve relpath side:
    #!/usr/bin/env bash
    set -euo pipefail
    fish -c 'capture-resolve "$argv[1]" "$argv[2]"' -- {{quote(relpath)}} {{quote(side)}}

# === Shared Helpers ===
rebuild_log := "/tmp/nixerator-rebuild.log"
upgrade_log := "/tmp/nixerator-upgrade.log"

# Auto-commit + push a refreshed flake.lock so it never lingers uncommitted or
# unpushed. Shared by the four recipes that re-lock an input and then need the
# identical commit/push dance: upgrade, quiet-upgrade, bump-upsight,
# bump-hyprflake. No-op when flake.lock is unchanged.
#
# Push is gated to main (post-rebuild only pushes main too) and non-fatal: a
# failed push keeps the local commit and warns. A failed commit is non-fatal
# too -- these run at the tail of a successful rebuild and must not turn a
# good rebuild into a failed recipe.
#
# mode: "interactive" (gum style) or "quiet" (plain echo)
# sign: "1" to GPG-sign the commit (`git commit -S`), "0" for a plain commit.
#       The four call sites had diverged here -- bump-hyprflake signed, the
#       other three did not -- so the flag preserves each caller's existing
#       behaviour rather than silently picking one. Default is unsigned,
#       matching the majority.
[private]
commit-lock msg mode="quiet" sign="0":
    #!/usr/bin/env bash
    set -uo pipefail
    notice() { if [[ "{{mode}}" == "interactive" ]]; then gum style --foreground 82 "$1"; else echo "$1"; fi; }
    warn()   { if [[ "{{mode}}" == "interactive" ]]; then gum style --foreground 220 "$1"; else echo "⚠ $1"; fi; }

    git diff --quiet flake.lock && exit 0

    commit_ok=true
    if git add flake.lock; then
        if [[ "{{sign}}" == "1" ]]; then
            git commit -qS -m "{{msg}}" || commit_ok=false
        else
            git commit -q -m "{{msg}}" || commit_ok=false
        fi
    else
        commit_ok=false
    fi
    if ! $commit_ok; then
        warn "flake.lock updated but commit failed — commit it manually."
        exit 0
    fi
    notice "Committed flake.lock."

    [[ "$(git branch --show-current 2>/dev/null)" == "main" ]] || exit 0
    if git push -q origin main 2>/dev/null; then
        notice "Pushed flake.lock to origin/main."
    else
        warn "flake.lock committed but push failed — push manually."
    fi

# Commit + push cfg/plugin-config.nix and the cfg/claude-stack snapshot if
# bump-claude-skills changed the pin or the snapshot.
#
# Separate from commit-lock rather than folding into it: commit-lock's
# pathspec is hardcoded to flake.lock and is called from more places
# (bump-upsight, bump-hyprflake) than just the two upgrade recipes, so
# widening its contract risked committing this file from callers that never
# touch it. Same shape otherwise -- only stages/commits/pushes when this one
# file actually changed.
[private]
commit-plugin-config msg mode="quiet" sign="0":
    #!/usr/bin/env bash
    set -uo pipefail
    notice() { if [[ "{{mode}}" == "interactive" ]]; then gum style --foreground 82 "$1"; else echo "$1"; fi; }
    warn()   { if [[ "{{mode}}" == "interactive" ]]; then gum style --foreground 220 "$1"; else echo "⚠ $1"; fi; }

    # The pin and the claude-stack snapshot must land in one commit.
    file="modules/apps/cli/claude-code/cfg/plugin-config.nix"
    stack_dir="modules/apps/cli/claude-code/cfg/claude-stack"
    git diff --quiet -- "$file" "$stack_dir" && exit 0

    commit_ok=true
    if git add -- "$file" "$stack_dir"; then
        if [[ "{{sign}}" == "1" ]]; then
            git commit -qS -m "{{msg}}" || commit_ok=false
        else
            git commit -q -m "{{msg}}" || commit_ok=false
        fi
    else
        commit_ok=false
    fi
    if ! $commit_ok; then
        warn "$file updated but commit failed — commit it manually."
        exit 0
    fi
    notice "Committed $file."

    [[ "$(git branch --show-current 2>/dev/null)" == "main" ]] || exit 0
    if git push -q origin main 2>/dev/null; then
        notice "Pushed $file to origin/main."
    else
        warn "$file committed but push failed — push manually."
    fi

# Secrets freshness nudge, run at the top of every switch recipe. A rebuild
# reads ~/.config/nixos-secrets/secrets.json at eval time, so a stale render can
# bake outdated values into the system. This is a pure local mtime check -- no
# 1Password, no network -- so it never slows or blocks a rebuild. It stays quiet
# unless secrets.json.tpl has moved ahead of the last render (a secret was added
# or rotated but not yet rendered on this host) or the host has never rendered at
# all. In that case a human or agent gets a 1s window to abort and run
# `just render-secrets`; otherwise the rebuild continues.
[private]
secrets-nudge:
    #!/usr/bin/env bash
    set -uo pipefail
    tpl="secrets.json.tpl"
    cache="$HOME/.config/nixos-secrets/secrets.json"
    if [[ -f "$tpl" ]] && { [[ ! -f "$cache" ]] || [[ "$tpl" -nt "$cache" ]]; }; then
        echo "⚠ secrets.json.tpl has changed since the last render (or was never rendered on this host)."
        echo "  If a secret was added or rotated, run: just render-secrets"
        echo "  Continuing rebuild in 1s -- Ctrl-C to abort."
        sleep 1
    fi
    # Snapshot staleness: only on a host that can reach 1Password (qbert). A clean
    # `just check-snapshot` writes the stamp below; no stamp, or one older than 7
    # days, means nobody has confirmed gopass still matches 1Password.
    stamp="${XDG_STATE_HOME:-$HOME/.local/state}/nixerator/snapshot-verified"
    if command -v op >/dev/null 2>&1; then
        if [[ ! -f "$stamp" ]] || [[ -n "$(find "$stamp" -mtime +7 2>/dev/null)" ]]; then
            echo "⚠ The gopass snapshot has not been checked against 1Password in over 7 days."
            echo "  Run: just check-snapshot   (refresh with: just import-secrets-to-gopass --update)"
        fi
    fi

# Pre-rebuild: capture runtime ~/.claude/* edits back into the source tree
# before activation overwrites them with the previously-captured version.
# Without this, any change made directly to a managed file (CLAUDE.md,
# settings.json, agents, skills, output-styles, plugin metadata) between
# rebuilds is silently lost when the activation script runs.
#
# DMS (dank) is captured here too, and the ordering is deliberate: dank-capture
# harvests the live ~/.config/DankMaterialShell/settings.json into
# dank-profiles/<group>.json BEFORE the rebuild evaluates the flake, so the same
# rebuild's dank seed re-derives exactly what was captured (live == seed marker)
# instead of tripping the seed clobber-guard's "un-captured GUI edits" warning.
# Capturing after activation would lag a rebuild and warn. The dank module
# preserves un-captured edits rather than wiping them, so there is no data-loss
# risk. Unlike the Claude Code capture (qbert-only), DMS capture runs on EVERY host: any
# workstation may contribute DMS settings to the shared profile. The captures are
# never auto-committed -- post-rebuild surfaces the diff for you to review, so a
# host with divergent DMS state can't silently clobber the shared profile.
# mode: "interactive" (gum spin) or "quiet" (plain echo)
[private]
pre-rebuild mode="quiet":
    #!/usr/bin/env bash
    set -uo pipefail
    # DMS (dank): host-agnostic, so capture BEFORE the qbert gate below. Writes
    # the live settings into dank-profiles/ so this same rebuild seeds them.
    if command -v dank-capture >/dev/null 2>&1 && [[ -e "$HOME/.config/DankMaterialShell/settings.json" ]]; then
        if [[ "{{mode}}" == "interactive" ]]; then
            gum spin --spinner dot --title "Capturing live DMS settings (pre-rebuild)..." \
                -- bash -c 'dank-capture &>/dev/null' || gum style --foreground 220 "DMS pre-capture failed (non-fatal)"
        else
            echo "Capturing live DMS settings (pre-rebuild)..."
            dank-capture &>/dev/null || echo "DMS pre-capture failed (non-fatal)"
        fi
    fi
    # The Claude Code capture flows live ~/.claude state into the repo. Only qbert
    # is the designated source -- other hosts (srv, ...) carry
    # narrower live state and would silently regress the repo if allowed to
    # auto-capture. For ad-hoc captures from another host (e.g. a newly
    # installed skill), run `just capture` explicitly.
    case "$(hostname)" in
        qbert) ;;
        *) exit 0 ;;
    esac
    if [[ "{{mode}}" == "interactive" ]]; then
        gum spin --spinner dot --title "Capturing live Claude Code config (pre-rebuild)..." \
            -- bash -c 'fish -c "claude-capture" &>/dev/null' || gum style --foreground 220 "Pre-capture failed (non-fatal)"
    else
        echo "Capturing live Claude Code config (pre-rebuild)..."
        fish -c 'claude-capture' &>/dev/null || echo "Pre-capture failed (non-fatal)"
    fi

# Post-rebuild: sync plugins, restart DMS, capture config, check for changes
# mode: "interactive" (gum spin) or "quiet" (plain echo)
#
# DankMaterialShell loads ~/.config/DankMaterialShell/settings.json once at
# startup and does not live-watch it, so a rebuild that rewrites that file
# (e.g. a hyprflake dank settings change) has no visible effect until the
# running shell is restarted. We bounce dms.service here, guarded on is-active
# so headless hosts without the desktop shell skip it.
#
# The bounce is ALSO skipped when the screen is locked. DMS owns the
# ext-session-lock surface while locked; restarting it kills that client
# without unlocking, so Hyprland keeps the session locked (its emergency
# fallback) and the freshly started DMS crash-loops on the orphaned lock
# (wl_display "invalid object") until the lock clears. If the screen idle-locks
# during a long rebuild, an unguarded restart here is exactly that collision.
# The lock check runs immediately before the restart, after update-skills, not
# at recipe start: a sample taken before the slow steps goes stale.
[private]
post-rebuild mode="quiet":
    #!/usr/bin/env bash
    set -uo pipefail
    # Sync/skills-update flow repo -> live (safe on every host).
    # Capture flows live -> repo; only qbert is the designated capture source.
    # For ad-hoc captures from another host, run `just capture` explicitly.
    is_capture_source=false
    case "$(hostname)" in
        qbert) is_capture_source=true ;;
    esac
    # Detect an active screen lock so the DMS bounce below can skip it (see the
    # recipe header). Any of the user's sessions reporting LockedHint=yes counts.
    # A function, not a one-time sample: update-skills below can run for minutes,
    # long enough for the idle timer to lock the screen after a sample taken here,
    # so the check runs again right before the restart.
    screen_locked() {
        loginctl --no-legend list-sessions 2>/dev/null | awk -v u="$USER" '$3==u{print $1}' \
            | xargs -r -I{} loginctl show-session {} -p LockedHint --value 2>/dev/null \
            | grep -q '^yes$'
    }
    if [[ "{{mode}}" == "interactive" ]]; then
        # Plugins are synced declaratively at activation (settings.json
        # overlay from cfg/plugin-config.nix); no runtime sync step needed.
        # Run visibly (not inside a gum spin) so claude-skill-updates'
        # "updated N skill(s)" report reaches the terminal; the spinner's
        # &>/dev/null would otherwise swallow it. The desktop notify-send
        # still fires regardless.
        echo "Updating skills..."
        just update-skills || gum style --foreground 220 "Skill update failed (non-fatal)"
        if systemctl --user is-active --quiet dms.service; then
            if screen_locked; then
                gum style --foreground 220 "Screen locked; skipping DMS restart (would orphan the session lock). Run 'systemctl --user restart dms.service' after unlocking."
            else
                gum spin --spinner dot --title "Restarting DankMaterialShell..." \
                    -- bash -c 'systemctl --user restart dms.service' || gum style --foreground 220 "DMS restart failed (non-fatal)"
            fi
        fi
        if command -v hyprflake-updates >/dev/null 2>&1; then
            hyprflake-updates || true
        fi
        if $is_capture_source; then
            gum spin --spinner dot --title "Capturing Claude Code config..." \
                -- bash -c 'fish -c "claude-capture" &>/dev/null' || gum style --foreground 220 "Capture failed (non-fatal)"
        fi
    else
        # Plugins synced declaratively at activation; no runtime sync step.
        echo "Updating skills..."
        just update-skills || echo "Skill update failed (non-fatal)"
        if systemctl --user is-active --quiet dms.service; then
            if screen_locked; then
                echo "Screen locked; skipping DMS restart (would orphan the session lock). Run 'systemctl --user restart dms.service' after unlocking."
            else
                echo "Restarting DankMaterialShell..."
                systemctl --user restart dms.service || echo "DMS restart failed (non-fatal)"
            fi
        fi
        if command -v hyprflake-updates >/dev/null 2>&1; then
            echo "Checking for DankMaterialShell / Hyprland updates..."
            hyprflake-updates || true
        fi
        if $is_capture_source; then
            echo "Capturing Claude Code config..."
            fish -c 'claude-capture' || echo "Capture failed (non-fatal)"
        fi
    fi

    # Auto-commit + push captured state so a rebuild leaves nothing uncommitted.
    #
    # Branch gate: we only auto-commit + push when HEAD is `main`. On any other
    # branch we fall back to surfacing the diff for manual review, so capture
    # commits never land on an unrelated feature branch.
    #
    # Scope: commits use the pathspec form `git commit -- <paths>`, which records
    # ONLY the named capture paths. This is load-bearing — `quiet-rebuild` runs
    # `git add -A` (so the flake sees untracked files) before calling this
    # recipe, so a bare `git commit` would sweep the entire index into the
    # capture commit. The pathspec form ignores everything staged for other
    # paths; the preceding `git add -- <paths>` only ensures new/modified capture
    # files are staged. Net effect: scoped commit regardless of what else is
    # staged, and never a `git add -A` commit.
    #
    # Host gate: the Claude Code capture stays gated to the capture source
    # (qbert) via is_capture_source; DMS (dank) settings commit on every host.
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
    on_main=false
    [[ "$branch" == "main" ]] && on_main=true
    did_commit=false

    notice() { if [[ "{{mode}}" == "interactive" ]]; then gum style --foreground 82 "$1"; else echo "$1"; fi; }
    warn()   { if [[ "{{mode}}" == "interactive" ]]; then gum style --foreground 220 "$1"; else echo "$1"; fi; }

    # commit_captures <label> <commit-msg> <path>...
    # On main: stage + pathspec-commit exactly the given paths, set did_commit.
    # Off main: surface the diff for manual review (the pre-auto-commit behaviour).
    commit_captures() {
        local label="$1" msg="$2"; shift 2
        local paths=("$@")
        [[ -z "$(git status --porcelain -- "${paths[@]}" 2>/dev/null)" ]] && return 0
        echo ""
        if $on_main; then
            git add -- "${paths[@]}" 2>/dev/null || true
            # `git commit -- <pathspec>` aborts the WHOLE commit if any pathspec
            # matches no tracked files (a capture path that produced no diffs and
            # holds nothing git-known). Commit only the paths that actually have
            # staged changes so one empty capture path can't sink a sibling
            # path's real changes.
            local committable=()
            for p in "${paths[@]}"; do
                git diff --cached --quiet -- "$p" 2>/dev/null || committable+=("$p")
            done
            [[ ${#committable[@]} -eq 0 ]] && return 0
            if git commit -q -m "$msg" -- "${committable[@]}"; then
                did_commit=true
                notice "$label captured and committed: $msg"
                notify-send "Nixerator" "$label captured and committed" 2>/dev/null || true
            else
                warn "$label captured but commit failed — commit manually:"
                warn "  git add ${committable[*]} && git commit -m \"$msg\" -- ${committable[*]}"
                notify-send "Nixerator" "$label capture commit failed" 2>/dev/null || true
            fi
        else
            warn "$label captured (on branch '$branch', not main) — review and commit manually:"
            warn "  git add ${paths[*]} && git commit -m \"$msg\" -- ${paths[*]}"
            notify-send "Nixerator" "$label captured — review and commit" 2>/dev/null || true
        fi
    }

    if $is_capture_source; then
        commit_captures "Claude Code config" \
            'chore(claude-code): update captured config state' \
            modules/apps/cli/claude-code/config
    fi
    # DMS (dank) settings are captured in pre-rebuild (before the seed) on EVERY
    # host -- not gated to qbert -- so commit any change on its own scope here.
    commit_captures "DMS settings" \
        'chore(dank): update captured DMS settings' \
        dank-profiles

    # Push once if anything was committed. did_commit is only ever set on main,
    # so this only pushes main. A failed push (diverged remote, no upstream) is
    # non-fatal: keep the local commit(s), warn, and let the rebuild finish.
    if $did_commit; then
        if git push -q origin main 2>/dev/null; then
            notice "Pushed captured config to origin/main"
            notify-send "Nixerator" "Captured config pushed to origin/main" 2>/dev/null || true
        else
            warn "Capture commit(s) made but push failed — resolve manually: git pull --rebase origin main && git push origin main"
            notify-send "Nixerator" "Capture push failed — resolve manually" 2>/dev/null || true
        fi
    fi

# === Quiet Recipes ===

# Quiet rebuild -- captures output, shows only errors on failure
[group('rebuild')]
quiet-rebuild:
    #!/usr/bin/env bash
    set -uo pipefail

    # Pre-rebuild guard: warn about uncommitted plugin changes
    if ! git diff --quiet modules/apps/cli/claude-code/config/plugins/ 2>/dev/null; then
        echo "⚠ Uncommitted plugin changes from a previous sync. Commit or discard before rebuilding."
    fi

    just secrets-nudge
    just pre-rebuild quiet

    echo "Rebuilding (quiet mode)..."
    git add -A
    trap 'git restore --staged .' EXIT
    rc=0
    sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild switch --impure --flake {{host_flake}} &> {{rebuild_log}} || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Rebuild succeeded. Full log: {{rebuild_log}}"

        just post-rebuild quiet
    else
        just filter-log {{rebuild_log}}
        echo "Rebuild FAILED (exit $rc). Use a Nix subagent to diagnose {{rebuild_log}} and fix the issue."
        exit "$rc"
    fi

# Quiet upgrade -- captures output, shows only errors on failure
[group('rebuild')]
quiet-upgrade:
    #!/usr/bin/env bash
    set -uo pipefail
    just secrets-nudge
    just pre-rebuild quiet
    echo "Upgrading (quiet mode)..."
    cp flake.lock flake.lock-backup-{{timestamp}}
    # Keep only the 5 newest lock backups.
    ls -1t flake.lock-backup-* 2>/dev/null | tail -n +6 | xargs -r rm -f
    rc=0
    # &&-chain so a failed `nix flake update` (or claude-skills pin bump)
    # aborts instead of rebuilding on stale/half-updated pins (a bare `;`
    # group would mask its exit status). claude-skills (dk/kong-cs/gitops)
    # isn't a flake input -- it's a commit-SHA pin in cfg/plugin-config.nix,
    # so `nix flake update` never touches it; bump-plugin-marketplace-sha.sh
    # does, the same way this bumps flake.lock.
    {
        nix flake update \
            && bash modules/apps/cli/claude-code/cfg/scripts/bump-plugin-marketplace-sha.sh claude-skills bashfulrobot/claude-skills main \
            && sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild switch --impure --upgrade --flake {{host_flake}} \
            && just ref::voxtype-setup
    } &> {{upgrade_log}} || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Upgrade succeeded. Full log: {{upgrade_log}}"
        just commit-lock "chore(flake): update flake lock"
        just commit-plugin-config "chore(claude-code): bump claude-skills marketplace pin"

        just post-rebuild quiet
    else
        just filter-log {{upgrade_log}}
        echo "Upgrade FAILED (exit $rc). Use a Nix subagent to diagnose {{upgrade_log}} and fix the issue."
        exit "$rc"
    fi

# Bump the `upsight` input (github:bashfulrobot/upsight) to latest + rebuild current host; commits + pushes flake.lock to main. For iterating on the app.
[doc('Bump the upsight input to latest + rebuild; commits + pushes flake.lock')]
[group('bump')]
bump-upsight:
    #!/usr/bin/env bash
    set -uo pipefail
    just secrets-nudge
    just pre-rebuild quiet
    echo "Bumping upsight input + rebuilding (quiet mode)..."
    # Back up the lock so a failed bump reverts cleanly and never leaves the tree
    # pinned to a broken upsight commit (an un-buildable next rebuild).
    cp flake.lock flake.lock-backup-bump
    rc=0
    # &&-chain so a failed input update aborts instead of rebuilding on the old
    # lock (a bare `;` group would mask its exit status).
    {
        # --refresh bypasses Nix's tarball-ttl (default 1h) so back-to-back
        # iterations always re-query GitHub HEAD instead of re-locking to a
        # cached commit (which silently no-ops the rebuild).
        nix flake update upsight --refresh \
            && sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild switch --impure --flake {{host_flake}}
    } &> {{rebuild_log}} || rc=$?
    # `nixos-rebuild switch` exits non-zero when a unit fails to (re)start during
    # activation (e.g. systemd-bless-boot on a boot entry without a counter) even
    # though the new system built and activated fine. Only revert when the build
    # never reached activation (a genuinely un-buildable pin). A non-zero exit that
    # still printed "activating the configuration" is unit-restart noise — an
    # idempotent re-run advances no profile either, so gate on activation, not on
    # the exit code or a profile diff.
    if [[ "$rc" -eq 0 ]] || grep -qF 'activating the configuration' {{rebuild_log}}; then
        if [[ "$rc" -ne 0 ]]; then
            echo "⚠ New config activated but a unit failed to (re)start (exit $rc). Review {{rebuild_log}}."
        fi
        rm -f flake.lock-backup-bump
        echo "upsight bumped + rebuilt. Full log: {{rebuild_log}}"
        just commit-lock "chore(flake): bump upsight input"

        just post-rebuild quiet
    else
        # Revert the failed bump so flake.lock isn't left pointing at a broken
        # upsight commit; the system stays buildable on the prior good pin.
        mv -f flake.lock-backup-bump flake.lock
        echo "Reverted flake.lock (bump failed) — tree left on the prior good pin."
        just filter-log {{rebuild_log}}
        echo "upsight bump FAILED (exit $rc). Use a Nix subagent to diagnose {{rebuild_log}} and fix the issue."
        exit "$rc"
    fi

# One command: bump + push hyprflake's inputs in its repo, then pull + rebuild here. Reverts the lock if the rebuild fails.
[doc('Bump + push hyprflake inputs in its repo, then pull + rebuild here')]
[group('bump')]
bump-hyprflake hyprflake_path="/home/dustin/git/hyprflake":
    #!/usr/bin/env bash
    set -uo pipefail
    echo "==> hyprflake repo: bump + push its inputs ({{hyprflake_path}})"
    if ! ( cd "{{hyprflake_path}}" && just bump-hyprflake ); then
        echo "hyprflake bump failed — aborting before touching nixerator."
        exit 1
    fi
    just secrets-nudge
    just pre-rebuild quiet
    echo "Bumping hyprflake input + rebuilding (quiet mode)..."
    # Back up the lock so a failed bump reverts cleanly and never leaves the tree
    # pinned to an un-buildable hyprflake commit.
    cp flake.lock flake.lock-backup-bump
    rc=0
    {
        # --refresh bypasses Nix's tarball-ttl so the just-pushed hyprflake HEAD
        # is re-queried instead of a cached commit (which would no-op the bump).
        nix flake update hyprflake --refresh \
            && sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild switch --impure --flake {{host_flake}}
    } &> {{rebuild_log}} || rc=$?
    # `nixos-rebuild switch` exits non-zero when a unit fails to (re)start during
    # activation (e.g. systemd-bless-boot on a boot entry without a counter) even
    # though the new system built and activated fine. Only revert when the build
    # never reached activation (a genuinely un-buildable pin). A non-zero exit that
    # still printed "activating the configuration" is unit-restart noise — an
    # idempotent re-run advances no profile either, so gate on activation, not on
    # the exit code or a profile diff.
    if [[ "$rc" -eq 0 ]] || grep -qF 'activating the configuration' {{rebuild_log}}; then
        if [[ "$rc" -ne 0 ]]; then
            echo "⚠ New config activated but a unit failed to (re)start (exit $rc). Review {{rebuild_log}}."
        fi
        rm -f flake.lock-backup-bump
        echo "hyprflake bumped + rebuilt. Full log: {{rebuild_log}}"
        # sign=1: this is the one lock-bumper that GPG-signs its commit. Kept
        # as-is when the four commit blocks were folded into commit-lock.
        just commit-lock "chore(flake): bump hyprflake input" quiet 1
        just post-rebuild quiet
    else
        # Revert so flake.lock isn't left on a broken hyprflake pin.
        mv -f flake.lock-backup-bump flake.lock
        echo "hyprflake bump/rebuild FAILED (exit $rc), reverted flake.lock. Log: {{rebuild_log}}"
        exit "$rc"
    fi

# Remote rebuild — pull and rebuild on another nixerator host over SSH.
#
# Workflow: commit + push from this machine, then `just remote-rebuild qbert`.
# The remote SSHes back to GitHub via your forwarded ssh-agent (requires the
# host to have forwardAgent=true in modules/system/ssh/default.nix), pulls
# fast-forward only, then runs `just qr` of its own host configuration.
#
# Secrets: rebuilds read ~/.config/nixos-secrets/secrets.json on the target
# host. They are NOT re-rendered here — that's `just render-secrets` (local) or
# `just push-secrets <host>` (render + scp to a peer), run manually when 1Password
# values change. See extras/docs/secrets.md.
[doc('Pull and rebuild on another nixerator host over SSH')]
[group('fleet')]
remote-rebuild host repo_path="~/git/nixerator":
    #!/usr/bin/env bash
    set -uo pipefail
    case "{{host}}" in
        qbert|srv) ;;
        *)
            echo "Refusing to ssh to unrecognized host: {{host}}"
            echo "Allowed: qbert, srv"
            exit 1
            ;;
    esac
    echo "Rebuilding {{host}} via SSH..."
    rc=0
    ssh -A -o BatchMode=yes -o ConnectTimeout=5 "{{host}}" \
        "cd {{repo_path}} && git pull --ff-only && just qr" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Remote rebuild on {{host}} succeeded."
    else
        echo "Remote rebuild on {{host}} FAILED (exit $rc)."
        exit "$rc"
    fi

# Remote upgrade — pull and full upgrade (flake update + rebuild) on another
# nixerator host over SSH. Same prereqs as `remote-rebuild`. Heavier than
# `rr` because the remote runs `nix flake update` before rebuilding.
[doc('Pull and full-upgrade another nixerator host over SSH')]
[group('fleet')]
remote-upgrade host repo_path="~/git/nixerator":
    #!/usr/bin/env bash
    set -uo pipefail
    case "{{host}}" in
        qbert|srv) ;;
        *)
            echo "Refusing to ssh to unrecognized host: {{host}}"
            echo "Allowed: qbert, srv"
            exit 1
            ;;
    esac
    echo "Upgrading {{host}} via SSH..."
    rc=0
    ssh -A -o BatchMode=yes -o ConnectTimeout=5 "{{host}}" \
        "cd {{repo_path}} && git pull --ff-only && just qu" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Remote upgrade on {{host}} succeeded."
    else
        echo "Remote upgrade on {{host}} FAILED (exit $rc)."
        exit "$rc"
    fi

# Render Nix-eval secrets from the secauto gopass snapshot into
# ~/.config/nixos-secrets/secrets.json. No 1Password, no prompt; rebuilds in
# between read the cached file. To pick up a changed 1Password value, refresh the
# snapshot first (`just import-secrets-to-gopass` on qbert, then pull).
[doc('Render Nix-eval secrets from the gopass snapshot into ~/.config/nixos-secrets/')]
[group('secrets')]
render-secrets:
    @render-secrets

# Render from 1Password (`op inject`) and restore the identity-class keys (SSH keys,
# git-crypt keys, incus-ui.pfx). Needed only on a new workstation install, because
# those files are never copied into gopass. Needs a 1Password desktop session.
[doc('Render from 1Password and restore SSH/git-crypt keys (new workstation install)')]
[group('secrets')]
render-secrets-op:
    @render-secrets --from op

# Render the same file from the secauto gopass store instead of 1Password. No
# `op`, no service-account token, no desktop prompt: safe to run headless (srv,
# a timer, an SSH session). A key whose entry is missing or empty is left out of
# the file and named on stderr. Document-backed files still need `render-secrets`.
[doc('Render secrets.json from the secauto gopass store (no 1Password)')]
[group('secrets')]
render-secrets-gopass:
    @render-secrets --from gopass

# Drift check against the gopass store: reports which keys differ, never values.
[doc('Check the cached secrets.json against the gopass store (read-only)')]
[group('secrets')]
check-secrets-gopass:
    @render-secrets --from gopass --check

# One-time copy of every mapped value from 1Password into the secauto gopass
# store (run on qbert, the writer). Values pipe op -> gopass and never print.
# Safe to rerun: present, non-empty entries are skipped.
[doc('Import 1Password values into the secauto gopass store (flags: --update --check --mirror --documents --dry-run --desktop)')]
[group('secrets')]
import-secrets-to-gopass *args:
    @bash extras/helpers/import-op-to-gopass.sh {{args}}

# Compare every mapped 1Password value with the gopass snapshot by digest. Prints
# entry names only; exits non-zero on drift and records a stamp on a clean pass,
# which silences the staleness warning in the rebuild recipes. Run on qbert.
[doc('Check the gopass snapshot against 1Password (names only; run on qbert)')]
[group('secrets')]
check-snapshot:
    @bash extras/helpers/import-op-to-gopass.sh --check

# Render locally AND scp the rendered file to one or more peer hosts. Use
# after rotating a 1Password value, before running `just remote-rebuild <host>`
# against any peer that should see the new value.
#
#   just push-secrets srv
#   just push-secrets srv qbert
#
# Hostnames are validated against an allow-list; render-secrets itself also
# enforces the same allow-list. The recipe quotes each host individually so a
# host string containing shell metacharacters cannot inject commands.
[doc('Render secrets locally AND scp them to one or more peer hosts')]
[group('secrets')]
push-secrets +hosts:
    #!/usr/bin/env bash
    set -euo pipefail
    for host in {{hosts}}; do
        case "$host" in
            qbert|srv) ;;
            *)
                echo "Refusing to push to unrecognized host: $host"
                echo "Allowed: qbert, srv"
                exit 1
                ;;
        esac
    done
    render-secrets --push {{hosts}}

# Copy the secauto GPG key (the one that decrypts the gopass store) to peer hosts.
# The key is streamed over SSH from this machine's keyring into the peer's, so it
# is never written to a file or printed. Idempotent: a host that already has the
# key is skipped. Run it on qbert, the host that holds the key.
#
#   just push-gpg-key srv
#
# Same host allow-list as render-secrets (qbert, srv, clanker). The Mac is not
# reachable this way; pull the key there with the command in extras/docs/secrets.md.
[doc('Copy the secauto GPG key to peer hosts over SSH (streamed, never on disk)')]
[group('secrets')]
push-gpg-key +hosts:
    #!/usr/bin/env bash
    set -euo pipefail
    for host in {{hosts}}; do
        case "$host" in
            qbert|srv|clanker) ;;
            *)
                echo "Refusing to push the GPG key to unrecognized host: $host"
                echo "Allowed: qbert, srv, clanker"
                exit 1
                ;;
        esac
    done
    fpr="$(gpg --list-keys --with-colons 'secauto automation' 2>/dev/null | awk -F: '/^fpr/ {print $10; exit}')"
    if [[ -z "$fpr" ]]; then
        echo "No 'secauto automation' key in this machine's keyring. Run this on qbert."
        exit 1
    fi
    for host in {{hosts}}; do
        if [[ "$host" == "$(hostname)" ]]; then
            echo "$host: this machine, skipped"
            continue
        fi
        if ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" "bash -c 'gpg --list-secret-keys --with-colons 2>/dev/null | grep -q $fpr'"; then
            echo "$host: key already present"
            continue
        fi
        gpg --export-secret-keys --armor "$fpr" \
            | ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" \
                "bash -c 'gpg --batch --pinentry-mode loopback --passphrase \"\" --import'" >/dev/null 2>&1
        ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" \
            "bash -c 'echo $fpr:6: | gpg --import-ownertrust'" >/dev/null 2>&1
        if ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" "bash -c 'gpg --list-secret-keys --with-colons 2>/dev/null | grep -q $fpr'"; then
            echo "$host: key imported"
        else
            echo "$host: FAILED to import the key"
            exit 1
        fi
    done

# Copy this machine's ~/.config/gws/ (gws OAuth credentials + encryption key)
# to one or more peer hosts that have no browser of their own to run
# `gws auth login` -- do the OAuth flow here first, then push the result.
#
#   just push-gws-creds srv
#
# Same host allow-list and per-host quoting as push-secrets above. Copies the
# whole directory (including gws's own cache/, which is harmless to carry
# along and not credential material) then tightens permissions on the peer
# to owner-only, since the transfer doesn't reliably preserve source modes.
# Uses rsync with a trailing slash on the source, NOT `scp -r`: scp -r nests
# the source dir one level deeper (~/.config/gws/gws/...) if the destination
# already exists, which it will on any host that's ever started the
# corresponding systemd service -- rsync's trailing-slash form merges into
# an existing target correctly instead. This recipe only ever references
# paths -- it never cats/reads the credential files themselves.
[doc("Copy this machine's gws OAuth credentials to a peer host")]
[group('secrets')]
push-gws-creds +hosts:
    #!/usr/bin/env bash
    set -euo pipefail
    for host in {{hosts}}; do
        case "$host" in
            qbert|srv) ;;
            *)
                echo "Refusing to push to unrecognized host: $host"
                echo "Allowed: qbert, srv"
                exit 1
                ;;
        esac
    done
    if [ ! -d "$HOME/.config/gws" ]; then
        echo "No ~/.config/gws locally -- run 'gws auth login' here first."
        exit 1
    fi
    for host in {{hosts}}; do
        ssh "$host" 'mkdir -p ~/.config/gws'
        rsync -a "$HOME/.config/gws/" "$host:~/.config/gws/"
        ssh "$host" 'chmod -R go-rwx ~/.config/gws'
        echo "Pushed gws credentials to $host"
    done

# Copy this machine's ~/.config/slack/ (slack-token-refresh's persistent
# Chromium profile + extracted xoxc/xoxd credentials.json) to a peer host
# that has no browser to log in with. The whole browser-profile directory
# has to travel, not just credentials.json -- it holds the session cookies
# `slack-token-refresh --headless` needs to refresh tokens later without an
# interactive login. This is a different credential store from gws's own
# (push-gws-creds above) and from claudoist's Slack MCP OAuth (Gap 1 in
# docs/superpowers/specs/2026-08-04-persistent-srv-tooling-design.md) --
# three separate Slack/Google auth paths, don't conflate them.
#
#   just push-slack-token-creds srv
#
# Same host allow-list/quoting/permission-tightening as push-gws-creds, and
# the same rsync-with-trailing-slash reasoning: `scp -r` nests the source
# dir one level deeper if the destination already exists (it will, on any
# host that's ever started the slack-token-refresh service), silently
# leaving the real profile invisible to a later `--headless` refresh. The
# browser profile is large (a few hundred MB) -- expect this to take a
# while over a slow link. Never reads the credential files' contents.
[doc("Copy this machine's slack-token-refresh credentials to a peer host")]
[group('secrets')]
push-slack-token-creds +hosts:
    #!/usr/bin/env bash
    set -euo pipefail
    for host in {{hosts}}; do
        case "$host" in
            qbert|srv) ;;
            *)
                echo "Refusing to push to unrecognized host: $host"
                echo "Allowed: qbert, srv"
                exit 1
                ;;
        esac
    done
    if [ ! -d "$HOME/.config/slack" ]; then
        echo "No ~/.config/slack locally -- run 'slack-token-refresh' here first."
        exit 1
    fi
    for host in {{hosts}}; do
        ssh "$host" 'mkdir -p ~/.config/slack'
        rsync -a "$HOME/.config/slack/" "$host:~/.config/slack/"
        ssh "$host" 'chmod -R go-rwx ~/.config/slack'
        echo "Pushed slack-token-refresh credentials to $host"
    done

# Render to a tempfile and diff against the live ~/.config/nixos-secrets/secrets.json.
# Exits non-zero if the gopass snapshot differs from the cached file. Read-only.
[doc('Check the cached secrets.json against the gopass snapshot (read-only)')]
[group('secrets')]
check-secrets:
    @render-secrets --check

# Detect a stale gopass snapshot: render from 1Password and diff against the live
# file. Non-zero means 1Password has changed since the last import. Needs a desktop
# session. Read-only.
[doc('Check the cached secrets.json against 1Password, to detect a stale gopass snapshot')]
[group('secrets')]
check-secrets-op:
    @render-secrets --from op --check

# Fetch the Okular signature + initials PNGs from the nixerator 1Password
# vault (Document items okular-signature + okular-initials) to
# ~/.kde/share/icons/{signature,initials}.png. One-time per host;
# re-run only if you rotate the documents in 1P.
[doc('Fetch the Okular signature + initials PNGs from 1Password (one-time)')]
[group('secrets')]
fetch-signatures:
    @./extras/helpers/fetch-okular-signatures.sh

# Write the gmailctl OAuth client credentials from the secauto gopass store
# (entries nixerator/gmailctl/client-id and client-secret) and render
# them into ~/.gmailctl/credentials.json (0600). One-time per host;
# re-run only if you rotate the OAuth client.
# Afterwards run `gmailctl init` to create token.json.
[doc('Write the gmailctl OAuth client credentials from gopass (one-time)')]
[group('secrets')]
fetch-gmailctl-creds:
    @./extras/helpers/fetch-gmailctl-credentials.sh

# Generic form: fetch the OAuth client into an arbitrary config dir / item.
# gmailctl picks its dir via --config (NOT cwd), so each account = its own dir.
# This subsumes the old `fetch-gmailctl-creds-kong` recipe, which was exactly
# this invocation with the Kong arguments baked in:
#   just fetch-gmailctl-creds-for ~/.gmailctl-kong gmailctl dustin@konghq.com
# then: gmailctl --config ~/.gmailctl-kong init
[doc('Fetch the gmailctl OAuth client into an arbitrary config dir / item')]
[group('secrets')]
fetch-gmailctl-creds-for dir item="gmailctl" account="":
    @./extras/helpers/fetch-gmailctl-credentials.sh "{{dir}}" "{{item}}" "{{account}}"

# === Aliases ===
alias r := rebuild
alias hft := hyprflake-test
alias up := upgrade
alias gc := clean
alias qr := quiet-rebuild
alias qu := quiet-upgrade
alias ub := bump-upsight
alias rr := remote-rebuild
alias ru := remote-upgrade
alias rs := render-secrets
alias rsg := render-secrets-gopass
alias ps := push-secrets
alias pgk := push-gpg-key
alias cs := check-secrets
alias csg := check-secrets-gopass
alias fs := fetch-signatures
alias fgc := fetch-gmailctl-creds
alias gen := generations
alias rb := rollback
