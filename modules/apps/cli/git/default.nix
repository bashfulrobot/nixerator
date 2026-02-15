{
  globals,
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.git;
  username = globals.user.name;

  # gcom — Git Commit Workflow Tool
  # Two-phase git workflow:
  #   gcom start [-w] [branch-name]  — create branch or worktree
  #   gcom finish [--squash]         — auto-commit, merge to main, cleanup
  gcom = pkgs.writeShellApplication {
    name = "gcom";

    runtimeInputs = with pkgs; [
      git
      git-crypt
      fzf
      coreutils
      gnused
      findutils
    ];

    text = ''
      # ── Colours ──────────────────────────────────────────────────────────
      RED=$'\033[0;31m'
      GREEN=$'\033[0;32m'
      YELLOW=$'\033[1;33m'
      CYAN=$'\033[0;36m'
      BOLD=$'\033[1m'
      NC=$'\033[0m'

      info()    { printf '%s▸ %s%s\n' "$CYAN" "$*" "$NC"; }
      ok()      { printf '%s✔ %s%s\n' "$GREEN" "$*" "$NC"; }
      warn()    { printf '%s⚠ %s%s\n' "$YELLOW" "$*" "$NC"; }
      die()     { printf '%s✖ %s%s\n' "$RED" "$*" "$NC" >&2; exit 1; }
      prompt()  { printf '%s%s%s' "$BOLD" "$*" "$NC"; }

      # ── Helpers ──────────────────────────────────────────────────────────
      require_git_repo() {
        git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"
      }

      current_branch() {
        git rev-parse --abbrev-ref HEAD
      }

      repo_name() {
        basename "$(git rev-parse --show-toplevel)"
      }

      is_worktree() {
        [[ -f "$(git rev-parse --show-toplevel)/.git" ]]
      }

      require_remote() {
        local remote="$1"
        git remote get-url "$remote" >/dev/null 2>&1 || die "remote not found: $remote"
      }

      default_branch() {
        local remote="''${1:-origin}"
        local head_ref
        head_ref="$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2>/dev/null)" || true
        if [[ -n "$head_ref" ]]; then
          echo "''${head_ref#"''${remote}"/}"
          return
        fi

        if git show-ref --verify --quiet "refs/remotes/$remote/main"; then
          echo "main"
          return
        fi

        die "unable to determine default branch for $remote (try: git remote set-head $remote -a)"
      }

      repo_path_with_branch() {
        local wanted_branch="$1"
        git worktree list --porcelain | awk -v wanted="refs/heads/$wanted_branch" '
          $1 == "worktree" { wt = $2 }
          $1 == "branch" && $2 == wanted { print wt; exit }
        '
      }

      # ── AI commit message generation ─────────────────────────────────────
      COMMIT_RULES='Generate a single conventional commit message for the following diff.
      Format: <type>(<scope>): <emoji> <description>
      Types and emojis: feat:✨ fix:🐛 docs:📝 style:💄 refactor:♻️ perf:⚡ test:✅ build:👷 ci:💚 chore:🔧 revert:⏪ security:🔒 deps:⬆️
      Rules:
      - scope is REQUIRED, lowercase, kebab-case module/area name
      - emoji goes AFTER the colon, before the description
      - description is imperative mood, lowercase start, no period, under 72 chars total
      - output ONLY the commit message line, nothing else
      Examples:
      feat(auth): ✨ add OAuth2 login flow
      fix(api): 🐛 resolve race condition in token refresh
      refactor(core): ♻️ extract validation into pure functions

      Diff:'

      generate_commit_msg() {
        local diff="$1"
        local msg=""

        if command -v gemini >/dev/null 2>&1; then
          info "generating commit message with gemini..."
          msg="$(printf '%s\n%s' "$COMMIT_RULES" "$diff" | gemini -p "Generate the commit message." 2>/dev/null | head -1)" || true
        fi

        if [[ -z "$msg" ]] && command -v claude >/dev/null 2>&1; then
          info "generating commit message with claude..."
          msg="$(printf '%s\n%s' "$COMMIT_RULES" "$diff" | claude -p "Generate the commit message." 2>/dev/null | head -1)" || true
        fi

        if [[ -z "$msg" ]]; then
          warn "no AI tool available, enter commit message manually"
          prompt "message: "
          read -r msg
        fi

        echo "$msg"
      }

      # ── start ────────────────────────────────────────────────────────────
      cmd_start() {
        local use_worktree=false
        local branch_name=""
        local remote="origin"
        local main_branch=""

        while [[ $# -gt 0 ]]; do
          case "$1" in
            -w|--worktree) use_worktree=true; shift ;;
            -*)           die "unknown flag: $1" ;;
            *)            branch_name="$1"; shift ;;
          esac
        done

        require_git_repo
        require_remote "$remote"
        info "refreshing remote refs from $remote..."
        git fetch --quiet "$remote"

        if [[ -z "$branch_name" ]]; then
          prompt "branch name: "
          read -r branch_name
          [[ -n "$branch_name" ]] || die "branch name required"
        fi

        main_branch="$(default_branch "$remote")"

        if [[ -n "$(git status --porcelain)" ]]; then
          die "working tree is not clean — commit or stash first"
        fi

        info "fetching $remote/$main_branch..."
        git fetch "$remote" "$main_branch"

        if git show-ref --verify --quiet "refs/heads/$branch_name"; then
          die "branch already exists: $branch_name"
        fi
        if git show-ref --verify --quiet "refs/remotes/$remote/$branch_name"; then
          die "remote branch already exists: $remote/$branch_name"
        fi

        if $use_worktree; then
          local repo
          repo="$(repo_name)"
          local wt_path
          wt_path="$(git rev-parse --show-toplevel)/../''${repo}-''${branch_name}"

          info "creating worktree at $wt_path"
          git worktree add "$wt_path" -b "$branch_name" "$remote/$main_branch"

          # Unlock git-crypt in the worktree
          local key_dir="$HOME/.ssh/git-crypt"
          if [[ -d "$key_dir" ]] && find "$key_dir" -maxdepth 1 -type f | head -1 | grep -q .; then
            info "select git-crypt key to unlock worktree:"
            local key
            key="$(find "$key_dir" -type f | fzf --prompt="git-crypt key> " --height=10)" || true
            if [[ -n "$key" ]]; then
              info "unlocking git-crypt in worktree..."
              git -C "$wt_path" crypt unlock "$key"
              ok "git-crypt unlocked"
            else
              warn "no key selected — worktree files will remain encrypted"
            fi
          else
            warn "no keys found in $key_dir — skipping git-crypt unlock"
          fi

          info "pushing branch to origin..."
          git -C "$wt_path" push -u "$remote" "$branch_name"

          ok "worktree ready at $wt_path"
          info "dropping you into the worktree..."
          cd "$wt_path" && exec "''${SHELL:-/bin/bash}"
        else
          info "creating branch $branch_name"
          git switch -c "$branch_name" "$remote/$main_branch"

          info "pushing branch to origin..."
          git push -u "$remote" "$branch_name"

          ok "branch $branch_name ready — you are now on it"
        fi
      }

      # ── finish ───────────────────────────────────────────────────────────
      cmd_finish() {
        local squash=false
        local remote="origin"
        local main_branch=""

        while [[ $# -gt 0 ]]; do
          case "$1" in
            --squash) squash=true; shift ;;
            -*)       die "unknown flag: $1" ;;
            *)        die "unexpected argument: $1" ;;
          esac
        done

        require_git_repo
        require_remote "$remote"
        info "refreshing remote refs from $remote..."
        git fetch --quiet "$remote"
        main_branch="$(default_branch "$remote")"

        local branch
        branch="$(current_branch)"

        [[ "$branch" != "$main_branch" ]] || die "already on $main_branch — nothing to finish"

        # Stage any uncommitted changes
        if [[ -n "$(git status --porcelain)" ]]; then
          info "staging all changes..."
          git add -A
        fi

        # Check there is something to commit
        if git diff --cached --quiet; then
          info "no staged changes — checking for existing commits on branch..."
          local ahead
          local compare_base="$remote/$main_branch"
          if ! git rev-parse --verify --quiet "refs/remotes/$remote/$main_branch" >/dev/null 2>&1; then
            if git rev-parse --verify --quiet "refs/heads/$main_branch" >/dev/null 2>&1; then
              compare_base="$main_branch"
              warn "remote base $remote/$main_branch not found; comparing against local $main_branch"
            else
              die "cannot determine comparison base for $main_branch"
            fi
          fi
          ahead="$(git rev-list --count "$compare_base..HEAD" 2>/dev/null)" || ahead=0
          if [[ "$ahead" -eq 0 ]]; then
            die "no changes to commit and no commits ahead of $main_branch"
          fi
          ok "found $ahead commit(s) ahead of $main_branch — skipping to merge"
        else
          # Generate commit message
          local diff
          diff="$(git diff --cached)"

          local msg
          msg="$(generate_commit_msg "$diff")"

          # Confirm with user
          echo ""
          printf '%sproposed commit message:%s\n' "$BOLD" "$NC"
          printf '  %s%s%s\n\n' "$GREEN" "$msg" "$NC"
          prompt "[y]es / [e]dit / [r]etry / [q]uit: "
          read -r choice

          case "$choice" in
            y|Y|"")
              ;;
            e|E)
              prompt "enter message: "
              read -r msg
              [[ -n "$msg" ]] || die "empty message"
              ;;
            r|R)
              msg="$(generate_commit_msg "$diff")"
              printf '  %s%s%s\n' "$GREEN" "$msg" "$NC"
              prompt "accept? [y/n]: "
              read -r yn
              [[ "$yn" =~ ^[yY] ]] || die "aborted"
              ;;
            *)
              die "aborted"
              ;;
          esac

          [[ -n "$msg" ]] || die "empty message"
          info "committing..."
          git commit -S -m "$msg"
          ok "committed"
        fi

        # Rebase onto latest main for ff-only merge
        info "fetching $remote/$main_branch..."
        git fetch "$remote" "$main_branch"

        local behind
        behind="$(git rev-list --count HEAD.."$remote/$main_branch" 2>/dev/null)" || behind=0
        if [[ "$behind" -gt 0 ]]; then
          info "rebasing onto $remote/$main_branch ($behind commits behind)..."
          git rebase "$remote/$main_branch" || die "rebase failed — resolve conflicts, then run: gcom finish"
        fi

        # Detect worktree before switching branches
        local in_worktree=false
        local wt_path=""
        local main_repo_path=""
        if is_worktree; then
          in_worktree=true
          wt_path="$(git rev-parse --show-toplevel)"
          main_repo_path="$(repo_path_with_branch "$main_branch")"
          [[ -n "$main_repo_path" ]] || die "could not find a worktree with $main_branch checked out"
        else
          main_repo_path="$(git rev-parse --show-toplevel)"
        fi

        # Merge into main
        info "switching to $main_branch in $main_repo_path..."
        if git -C "$main_repo_path" show-ref --verify --quiet "refs/heads/$main_branch"; then
          git -C "$main_repo_path" switch "$main_branch"
        else
          git -C "$main_repo_path" switch -c "$main_branch" "$remote/$main_branch"
        fi
        git -C "$main_repo_path" pull --ff-only "$remote" "$main_branch"

        if $squash; then
          info "squash-merging $branch..."
          git -C "$main_repo_path" merge --squash "$branch"
          local squash_msg
          squash_msg="$(git -C "$main_repo_path" log --format='%s' "$remote/$main_branch..$branch" | head -1)"
          [[ -n "$squash_msg" ]] || squash_msg="chore($branch): 🔧 squash merge $branch"
          git -C "$main_repo_path" commit -S -m "$squash_msg"
        else
          info "merging $branch (ff-only)..."
          git -C "$main_repo_path" merge --ff-only "$branch"
        fi

        info "pushing $main_branch..."
        git -C "$main_repo_path" push "$remote" "$main_branch"

        # Cleanup
        local cleanup_ok=true
        if $in_worktree && [[ -n "$wt_path" ]]; then
          info "removing worktree at $wt_path..."
          if ! git -C "$main_repo_path" worktree remove "$wt_path"; then
            warn "failed to remove worktree: $wt_path"
            cleanup_ok=false
          fi
        fi

        if git -C "$main_repo_path" show-ref --verify --quiet "refs/heads/$branch"; then
          if git -C "$main_repo_path" merge-base --is-ancestor "$branch" "$main_branch"; then
            info "deleting merged branch $branch..."
            if ! git -C "$main_repo_path" branch -d "$branch"; then
              warn "safe delete failed (likely due to upstream merge checks); force deleting local branch..."
              if ! git -C "$main_repo_path" branch -D "$branch"; then
                warn "failed to force delete local branch: $branch"
                cleanup_ok=false
              fi
            fi
          else
            info "branch $branch is not a merge ancestor of $main_branch; force deleting local branch..."
            if ! git -C "$main_repo_path" branch -D "$branch"; then
              warn "failed to force delete local branch: $branch"
              cleanup_ok=false
            fi
          fi
        else
          info "local branch already absent: $branch"
        fi

        if git -C "$main_repo_path" ls-remote --exit-code --heads "$remote" "$branch" >/dev/null 2>&1; then
          if ! git -C "$main_repo_path" push "$remote" --delete "$branch"; then
            warn "failed to delete remote branch: $remote/$branch"
            cleanup_ok=false
          fi
        else
          info "remote branch already absent: $remote/$branch"
        fi

        if $cleanup_ok; then
          ok "done — $branch merged into $main_branch and cleaned up"
        else
          warn "done — $branch merged into $main_branch, but cleanup had warnings"
        fi
      }

      # ── main ─────────────────────────────────────────────────────────────
      usage() {
        echo "usage: gcom <command> [options]"
        echo ""
        echo "commands:"
        echo "  start [-w|--worktree] [branch-name]   create a working branch"
        echo "  finish [--squash]                      commit, merge to main, cleanup"
        echo ""
        echo "flags:"
        echo "  -w, --worktree   use git worktree instead of branch"
        echo "  --squash         squash all commits into one on merge"
      }

      if [[ $# -eq 0 ]]; then
        usage
        exit 1
      fi

      command="$1"
      shift

      case "$command" in
        start)  cmd_start "$@" ;;
        finish) cmd_finish "$@" ;;
        -h|--help|help) usage ;;
        *) die "unknown command: $command" ;;
      esac
    '';
  };
in
{
  options = {
    apps.cli.git.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable git and related tools.";
    };
  };

  config = lib.mkIf cfg.enable {

    # System-level packages
    environment.systemPackages = with pkgs; [
      gcom
      git
      git-crypt
      git-filter-repo
    ];

    # Home Manager user configuration
    home-manager.users.${username} = {

      programs = {
        fish = {
          shellAliases = {
            g = "git";
            ga = "git add";
            gc = "git commit";
            gco = "git checkout";
            gst = "git status";
            gp = "git push";
            gpl = "git pull";
            gd = "git diff";
            gl = "git log";
            lg = "lazygit";
          };
        };
      };

      programs = {
        git = {
          enable = true;
          settings = {
            user = {
              inherit (globals.user) email;
              name = globals.user.fullName;
              signingkey = "~/.ssh/id_ed25519.pub";
            };
            init.defaultBranch = "main";
            pull.rebase = false;
            push.default = "simple";
            merge.ff = "only";

            # SSH signing configuration
            commit.gpgsign = true;
            tag.gpgsign = true;
            gpg.format = "ssh";
            gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";

            # Git aliases
            alias = {
              a = "add";
              c = "commit";
              co = "checkout";
              st = "status";
              br = "branch";
            };
          };
        };

        # Difftastic is now a separate program
        difftastic = {
          enable = true;
          git.enable = true;
          options = {
            background = "dark";
            color = "always";
          };
        };

        lazygit = {
          enable = true;
          settings = {
            git.parseEmoji = true;
            gui.theme = {
              lightTheme = false;
              nerdFontVersion = "3";
            };
          };
        };

        gh = {
          enable = true;
          gitCredentialHelper.enable = true;
          settings = {
            editor = lib.getExe pkgs.${globals.preferences.editor};
            git_protocol = "ssh";
            prompt = "enabled";
            aliases = {
              co = "pr checkout";
              pv = "pr view";
            };
          };
        };
      };

      # Create allowed_signers file for SSH signing
      home.file.".config/git/allowed_signers".text = ''
        ${globals.user.email} ${globals.git.gitPubSigningKey}
      '';

    };

  };
}
