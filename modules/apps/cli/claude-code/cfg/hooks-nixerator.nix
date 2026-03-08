{ lib }:

{
  # Nixerator-specific bash guards
  PostToolUse = [
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

    # Nixerator-specific nix content rules (hardcoded username, hyprland syntax)
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
}
