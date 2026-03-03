{ lib }:

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
                echo "[git-sync] Diverged — local and remote both have commits. Resolve manually."
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
