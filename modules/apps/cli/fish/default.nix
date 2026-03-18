{
  globals,
  lib,
  config,
  ...
}:

let
  cfg = config.apps.cli.fish;
in
{
  options = {
    apps.cli.fish.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable fish shell via home-manager.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Enable fish at system level (required for user shell)
    programs.fish.enable = true;

    # Home Manager user configuration
    home-manager.users.${globals.user.name} = {

      programs.fish = {
        enable = true;

        # Fish shell configuration
        shellInit = ''
          # Disable greeting
          set fish_greeting
        '';

        # Shell aliases
        shellAliases = {
          gs = "git status";
          ni = "nix run 'nixpkgs#nix-index' --extra-experimental-features 'nix-command flakes'";
          nix-info = "nix-info --markdown --sandbox --host-os";

          # Directory navigation
          gon = "cd ${globals.paths.nixerator}";
          goh = "cd ${globals.paths.hyprflake}";

          # NixOS operations
          upgrade = "cd ${globals.paths.nixerator} && just upgrade";
          rebuild = "cd ${globals.paths.nixerator} && just rebuild";
          gsp = "just sync-git";
          bt-toggle = "rfkill toggle bluetooth; rfkill list bluetooth | grep -q 'Soft blocked: yes'; and echo 'Bluetooth: OFF'; or echo 'Bluetooth: ON'";
        };

        # Custom functions
        functions = {
          kcfg = ''
            set -l clusters_dir "$HOME/.kube/clusters"
            set -l active_config "$HOME/.kube/config"

            if not test -d "$clusters_dir"
              echo "Error: $clusters_dir directory does not exist"
              return 1
            end

            set -l selected (find "$clusters_dir" -type f | fzf --prompt="Select kubeconfig: " --height=40% --border)

            if test -n "$selected"
              cp "$selected" "$active_config"
              echo "✓ Activated kubeconfig: $(basename $selected)"
            else
              echo "No selection made"
            end
          '';

          tcfg = ''
            set -l clusters_dir "$HOME/.talos/clusters"
            set -l active_config "$HOME/.talos/config"

            if not test -d "$clusters_dir"
              echo "Error: $clusters_dir directory does not exist"
              return 1
            end

            set -l selected (find "$clusters_dir" -type f | fzf --prompt="Select talosconfig: " --height=40% --border)

            if test -n "$selected"
              cp "$selected" "$active_config"
              echo "✓ Activated talosconfig: $(basename $selected)"
            else
              echo "No selection made"
            end
          '';

          copy = ''
            if test (count $argv) -gt 0
              if not test -f "$argv[1]"
                echo "Error: $argv[1] is not a file"
                return 1
              end
              wl-copy < "$argv[1]"
              echo "✓ Copied: $argv[1]"
            else
              set -l selected (fzf --prompt="Copy file: " --height=40% --border --preview="head -50 {}")
              if test -n "$selected"
                wl-copy < "$selected"
                echo "✓ Copied: $selected"
              else
                echo "No selection made"
              end
            end
          '';

          kns = ''
            set -l namespace (kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | fzf --prompt="Select namespace: " --height=40% --border)

            if test -n "$namespace"
              kubectl config set-context --current --namespace="$namespace"
              echo "✓ Switched to namespace: $namespace"
            else
              echo "No selection made"
            end
          '';
        };
      };

    };

  };
}
