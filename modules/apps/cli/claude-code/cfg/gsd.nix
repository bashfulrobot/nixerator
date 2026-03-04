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
      gsd
    ];
    text = ''
      settings="${homeDir}/.claude/settings.json"

      # Back up Nix-managed settings.json before GSD touches it
      if [ -f "$settings" ]; then
        cp "$settings" "$settings.nix-backup"
      fi

      # Run the GSD installer for Claude Code (global)
      get-shit-done-cc --claude --global "$@"

      # Restore the Nix-managed settings.json
      # GSD hooks are integrated via Nix, not via GSD's settings modifications
      if [ -f "$settings.nix-backup" ]; then
        mv "$settings.nix-backup" "$settings"
        echo "[gsd-install] Restored Nix-managed settings.json"
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
