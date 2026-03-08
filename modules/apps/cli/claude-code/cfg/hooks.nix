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

    # Enforce safe bash commands
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

              # Block nixos-rebuild (must use just qr / just qu)
              if echo "$cmd" | grep -qE '(^|\s|;|&&|\|)nixos-rebuild(\s|$)'; then
                echo "[bash-guard] ERROR: Do not run nixos-rebuild directly. Fix: use 'just qr' (quiet-rebuild) or 'just qu' (quiet-upgrade) instead."
                exit 1
              fi

              # Warn on git commit and git push (user normally handles these, but may request via /command)
              if echo "$cmd" | grep -qE '(^|\s|;|&&|\|)git\s+(commit|push)(\s|$)'; then
                echo "[bash-guard] WARNING: git commit/push detected. Only do this if the user explicitly asked. Do not commit or push on your own initiative."
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

              # Block direct nix-collect-garbage (use just recipes)
              if echo "$cmd" | grep -qE '(^|\s|;|&&|\|)nix-collect-garbage(\s|$)'; then
                echo "[bash-guard] ERROR: Do not run nix-collect-garbage directly. Fix: use the appropriate just recipe instead."
                exit 1
              fi
            '')
          ];
        }
      ];
    }

    # Enforce nix file content rules (synchronous checks)
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
              is_secrets=false
              if [[ "$file" == */secrets/* ]]; then
                is_secrets=true
              fi

              # Hardcoded username detection (outside secrets/)
              if [[ "$is_secrets" == false ]] && [[ -f "$file" ]]; then
                if grep -qE '/home/dustin|home-manager\.users\.dustin' "$file"; then
                  echo "[nix-content] ERROR: Hardcoded username detected in $file. Fix: use globals.user.name or globals.user.homeDirectory from settings/globals.nix instead."
                  exit 1
                fi
              fi

              # Plaintext secret patterns (outside secrets/)
              if [[ "$is_secrets" == false ]] && [[ -f "$file" ]]; then
                if grep -qEi '(password|apiKey|token|secret)\s*=\s*"[^"]+' "$file"; then
                  echo "[nix-content] WARNING: Possible plaintext secret in $file. Use agenix secrets in secrets/ directory instead of inline secret values."
                fi
              fi

              # Hyprland deprecated syntax
              if [[ "$file" == *hypr* ]] && [[ -f "$file" ]]; then
                if grep -qE 'windowrulev2' "$file"; then
                  echo "[nix-content] ERROR: Deprecated 'windowrulev2' found in $file. Fix: use block syntax 'windowrule {' (Hyprland 0.53+). See extras/docs/hyprland-windowrules.md."
                  exit 1
                fi
                if grep -qE '^\s*windowrule\s*=' "$file"; then
                  echo "[nix-content] ERROR: Single-line 'windowrule =' found in $file. Fix: use block syntax 'windowrule {' (Hyprland 0.53+). See extras/docs/hyprland-windowrules.md."
                  exit 1
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

    # Enforce module structure conventions
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

              # Check version literals in build/default.nix files
              if [[ "$file" == */build/default.nix ]]; then
                if grep -qE '^\s*version\s*=\s*"' "$file"; then
                  echo "[module-structure] ERROR: Hardcoded version literal in $file. Fix: versions should come from the 'versions' parameter (settings/versions.nix)."
                  exit 1
                fi
              fi

              # Only check module default.nix files under modules/
              if [[ "$file" != */modules/*/default.nix ]]; then
                exit 0
              fi

              # Skip if file has no options block (not a module definition)
              if ! grep -q 'options\.' "$file"; then
                exit 0
              fi

              # Extract expected namespace from path: modules/<cat>/<subcat>/<name>/default.nix
              mod_path=$(echo "$file" | sed -n 's|.*/modules/\(.*\)/default\.nix|\1|p')
              if [[ -z "$mod_path" ]]; then
                exit 0
              fi
              # Convert path separators to dots for namespace
              namespace=$(echo "$mod_path" | tr '/' '.')

              # Check enable option matches path
              if ! grep -q "options\.''${namespace}\.enable" "$file"; then
                echo "[module-structure] ERROR: Module at $file defines options but is missing 'options.''${namespace}.enable'. Fix: add 'options.''${namespace}.enable = lib.mkEnableOption \"...\";'."
                exit 1
              fi

              # Check config is wrapped in mkIf
              if ! grep -qE '(lib\.mkIf|mkIf)' "$file"; then
                echo "[module-structure] WARNING: Module at $file defines options but config is not wrapped in mkIf. Consider using 'config = lib.mkIf cfg.enable { ... };'."
              fi
            '')
          ];
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
