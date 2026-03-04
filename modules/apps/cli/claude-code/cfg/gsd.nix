{
  pkgs,
  versions,
  homeDir,
  ...
}:

let
  gsd = pkgs.callPackage ../build/gsd { inherit versions; };

  gsdInstall = pkgs.writeShellApplication {
    name = "gsd-install";
    runtimeInputs = [
      pkgs.nodejs
      pkgs.jq
      pkgs.diffutils
      gsd
    ];
    text = ''
      settings="${homeDir}/.claude/settings.json"

      # settings.json is a Nix-managed symlink to the store (read-only).
      # Temporarily replace it with a writable copy so GSD's installer can write to it,
      # then restore the original symlink afterward.
      nix_target=""
      if [ -L "$settings" ]; then
        nix_target="$(readlink -f "$settings")"
        cp --no-preserve=mode "$nix_target" "$settings.tmp"
        rm "$settings"
        mv "$settings.tmp" "$settings"
      fi

      # Run the GSD installer for Claude Code (global)
      get-shit-done-cc --claude --global "$@"

      # Compare what GSD wrote vs what Nix manages (hooks only)
      if [ -n "$nix_target" ] && [ -f "$settings" ]; then
        gsd_hooks=$(jq -S '.hooks // {}' "$settings")
        nix_hooks=$(jq -S '.hooks // {}' "$nix_target")

        if [ "$gsd_hooks" != "$nix_hooks" ]; then
          echo ""
          echo -e "\033[1;33m[gsd-install] ⚠ GSD hooks differ from Nix-managed settings!\033[0m"
          echo -e "\033[1;33m[gsd-install] Update gsd.nix to match. Diff (nix → gsd):\033[0m"
          diff --color=always \
            <(echo "$nix_hooks" | jq .) \
            <(echo "$gsd_hooks" | jq .) \
          || true
          echo ""
        fi
      fi

      # Restore the Nix-managed symlink
      if [ -n "$nix_target" ]; then
        rm -f "$settings"
        ln -s "$nix_target" "$settings"
        echo "[gsd-install] Restored Nix-managed settings.json symlink"
      fi
    '';
  };
in
{
  packages = [
    gsd
    gsdInstall
  ];

  hooks = {
    # GSD context monitor — tracks context window usage after tool calls
    PostToolUse = [
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "node ${homeDir}/.claude/hooks/gsd-context-monitor.js";
          }
        ];
      }
    ];

    # GSD update checker — runs on session start
    SessionStart = [
      {
        matcher = "startup";
        hooks = [
          {
            type = "command";
            command = "node ${homeDir}/.claude/hooks/gsd-check-update.js";
          }
        ];
      }
    ];
  };
}
