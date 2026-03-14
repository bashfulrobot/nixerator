{
  pkgs,
  desiredPlugins,
  ...
}:

let
  desiredPluginsJson = pkgs.writeText "claude-desired-plugins.json" (builtins.toJSON desiredPlugins);

  claudeSyncPlugins = pkgs.writeShellApplication {
    name = "claude-sync-plugins";
    runtimeInputs = [
      pkgs.jq
      pkgs.llm-agents.claude-plugins
    ];
    text = ''
      installed_file="$HOME/.claude/plugins/installed_plugins.json"
      desired_file="${desiredPluginsJson}"

      # Read desired plugins
      mapfile -t desired < <(jq -r '.[]' "$desired_file")

      if [[ ''${#desired[@]} -eq 0 ]]; then
        echo "[sync-plugins] No plugins declared in Nix config."
        exit 0
      fi

      # Read installed plugin keys (handle missing file)
      if [[ -f "$installed_file" ]]; then
        mapfile -t installed < <(jq -r '.plugins | keys[]' "$installed_file")
      else
        installed=()
      fi

      # Compute missing = desired - installed
      missing=()
      for plugin in "''${desired[@]}"; do
        found=false
        for inst in "''${installed[@]}"; do
          if [[ "$plugin" == "$inst" ]]; then
            found=true
            break
          fi
        done
        if [[ "$found" == "false" ]]; then
          missing+=("$plugin")
        fi
      done

      # Install missing plugins
      if [[ ''${#missing[@]} -gt 0 ]]; then
        echo "[sync-plugins] Installing ''${#missing[@]} missing plugin(s)..."
        for plugin in "''${missing[@]}"; do
          echo "[sync-plugins] Installing $plugin..."
          echo "y" | claude-plugins install "$plugin"
        done
      fi

      if [[ ''${#missing[@]} -eq 0 ]]; then
        echo "[sync-plugins] All plugins already installed."
      fi

      echo "[sync-plugins] Done."
    '';
  };
in
{
  packages = [
    claudeSyncPlugins
  ];
}
