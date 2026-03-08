{ lib }:

let
  # Detect default branch dynamically (works with main, master, develop, trunk, etc.)
  detectDefaultBranch = ''
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
    default_branch="''${default_branch:-main}"
  '';
in
{
  # Sync git state on session start (handles syncthing drift)
  SessionStart = [
    {
      matcher = "startup";
      hooks = [
        {
          type = "command";
          command = builtins.concatStringsSep " " [
            "bash"
            "-c"
            (lib.escapeShellArg ''
              git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
              branch=$(git rev-parse --abbrev-ref HEAD)
              git fetch origin 2>/dev/null || exit 0
              local_only=$(git log "origin/$branch..$branch" --oneline 2>/dev/null)
              remote_only=$(git log "$branch..origin/$branch" --oneline 2>/dev/null)
              if [ -n "$local_only" ] && [ -n "$remote_only" ]; then
                echo "[git-sync] Diverged -- local and remote both have commits. Resolve manually."
              elif [ -n "$remote_only" ]; then
                git reset "origin/$branch" >/dev/null 2>&1
                echo "[git-sync] Aligned git state with origin/$branch"
              elif [ -n "$local_only" ]; then
                echo "[git-sync] Unpushed local commits on $branch"
              fi
            '')
          ];
        }
      ];
    }

    # Branch awareness on session start
    {
      matcher = "startup";
      hooks = [
        {
          type = "command";
          command = builtins.concatStringsSep " " [
            "bash"
            "-c"
            (lib.escapeShellArg ''
              git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
              ${detectDefaultBranch}
              branch=$(git rev-parse --abbrev-ref HEAD)
              feature_branches=$(git branch --list --no-color | grep -v '^\*' | grep -vE "^\s*$default_branch$" | sed 's/^  //' || true)

              if [[ "$branch" == "$default_branch" ]]; then
                if [[ -n "$feature_branches" ]]; then
                  echo "[branch] On $default_branch. Feature branches available:"
                  echo "$feature_branches" | while read -r b; do echo "  - $b"; done
                  echo "Consider switching if one is relevant to your task."
                else
                  echo "[branch] On $default_branch. For non-trivial work, consider creating a feature branch."
                fi
              else
                msg="[branch] On $branch."
                counts=$(git rev-list --left-right --count "$default_branch...$branch" 2>/dev/null || true)
                if [[ -n "$counts" ]]; then
                  behind=$(echo "$counts" | awk '{print $1}')
                  ahead=$(echo "$counts" | awk '{print $2}')
                  msg="$msg Ahead: $ahead, behind: $behind vs $default_branch."
                fi
                uncommitted=$(git status --porcelain 2>/dev/null | wc -l)
                if [[ "$uncommitted" -gt 0 ]]; then
                  msg="$msg Uncommitted changes: $uncommitted files."
                fi
                echo "$msg"
              fi
            '')
          ];
        }
      ];
    }
  ];

  # Auto-format .nix files after edits (fire-and-forget)
  PostToolUse = [
    {
      matcher = "Edit|Write|MultiEdit";
      hooks = [
        {
          type = "command";
          command = builtins.concatStringsSep " " [
            "bash"
            "-c"
            (lib.escapeShellArg ''
              input=$(cat)
              file=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
              [[ "$file" == *.nix ]] || exit 0
              nix fmt "$file" 2>/dev/null || true
            '')
          ];
          async = true;
        }
      ];
    }

    # Edit-on-default-branch warning (once per session)
    {
      matcher = "Edit|Write|MultiEdit";
      hooks = [
        {
          type = "command";
          command = builtins.concatStringsSep " " [
            "bash"
            "-c"
            (lib.escapeShellArg ''
              git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
              ${detectDefaultBranch}
              branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
              [[ "$branch" == "$default_branch" ]] || exit 0
              flag="/tmp/claude-branch-warned.$PPID"
              [[ -f "$flag" ]] && exit 0
              touch "$flag"
              echo "[branch] You're editing on $default_branch. For non-trivial changes, consider a feature branch."
            '')
          ];
        }
      ];
    }

    # Enforce safe bash commands (global git guards)
    {
      matcher = "Bash";
      hooks = [
        {
          type = "command";
          command = builtins.concatStringsSep " " [
            "bash"
            "-c"
            (lib.escapeShellArg ''
              input=$(cat)
              cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
              [[ -n "$cmd" ]] || exit 0

              # Warn on git commit and git push (user normally handles these, but may request via /command)
              if echo "$cmd" | grep -qE '(^|\s|;|&&|\|)git\s+(commit|push)(\s|$)'; then
                ${detectDefaultBranch}
                warn="[bash-guard] WARNING: git commit/push detected. Only do this if the user explicitly asked. Do not commit or push on your own initiative."
                current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
                if [[ "$current_branch" == "$default_branch" ]]; then
                  warn="$warn\n[bash-guard] NOTE: You are committing to $default_branch. If this is non-trivial work, consider a feature branch first."
                fi
                echo -e "$warn"
              fi

              # Block --no-verify and --force on git commands (allow --force-with-lease)
              if echo "$cmd" | grep -qE '(^|\s|;|&&|\|)git\s'; then
                if echo "$cmd" | grep -qE '\-\-no-verify'; then
                  echo "[bash-guard] ERROR: Do not use --no-verify on git commands. Fix: fix the underlying hook issue instead of bypassing it."
                  exit 1
                fi
                # Match --force but not --force-with-lease
                if echo "$cmd" | grep -qP '\-\-force(?!-with-lease)(\s|$)' || echo "$cmd" | grep -qE '\s-f(\s|$)'; then
                  echo "[bash-guard] ERROR: Do not use --force on git commands. Fix: use --force-with-lease if you must force push."
                  exit 1
                fi
              fi
            '')
          ];
        }
      ];
    }

    # Warn on plaintext secrets in .nix files
    {
      matcher = "Edit|Write|MultiEdit";
      hooks = [
        {
          type = "command";
          command = builtins.concatStringsSep " " [
            "bash"
            "-c"
            (lib.escapeShellArg ''
              input=$(cat)
              file=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
              [[ "$file" == *.nix ]] || exit 0

              # Skip files inside secrets/ directory
              [[ "$file" != */secrets/* ]] || exit 0

              if [[ -f "$file" ]]; then
                if grep -qEi '(password|apiKey|token|secret)\s*=\s*"[^"]+' "$file"; then
                  echo "[nix-content] WARNING: Possible plaintext secret in $file. Use agenix secrets in secrets/ directory instead of inline secret values."
                fi
              fi
            '')
          ];
        }
      ];
    }

    # Run statix and deadnix on edited nix files (async, non-blocking)
    {
      matcher = "Edit|Write|MultiEdit";
      hooks = [
        {
          type = "command";
          command = builtins.concatStringsSep " " [
            "bash"
            "-c"
            (lib.escapeShellArg ''
              input=$(cat)
              file=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
              [[ "$file" == *.nix ]] || exit 0
              [[ -f "$file" ]] || exit 0

              warnings=""
              statix_out=$(statix check "$file" 2>/dev/null) && true
              if [[ -n "$statix_out" ]]; then
                warnings="[nix-lint] statix warnings in $file:\n$statix_out"
              fi

              deadnix_out=$(deadnix "$file" 2>/dev/null) && true
              if [[ -n "$deadnix_out" ]]; then
                if [[ -n "$warnings" ]]; then
                  warnings="$warnings\n"
                fi
                warnings="$warnings[nix-lint] deadnix warnings in $file:\n$deadnix_out"
              fi

              if [[ -n "$warnings" ]]; then
                echo -e "$warnings"
              fi
            '')
          ];
          async = true;
        }
      ];
    }
  ];

  # Desktop notification when Claude finishes a response
  Stop = [
    {
      hooks = [
        {
          type = "command";
          command = builtins.concatStringsSep " " [
            "bash"
            "-c"
            (lib.escapeShellArg ''
              input=$(cat)
              msg=$(echo "$input" | jq -r '.last_assistant_message // "Done"' 2>/dev/null | head -c 80)
              notify-send "Claude Code" "$msg" --icon=terminal 2>/dev/null || true
            '')
          ];
        }
      ];
    }
  ];
}
