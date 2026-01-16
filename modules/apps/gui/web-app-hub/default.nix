{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.gui.web-app-hub;
  username = globals.user.name;

  # Package the extraction script as a proper derivation
  extract-webapps = pkgs.writeShellApplication {
    name = "extract-webapps";

    runtimeInputs = with pkgs; [ coreutils gnugrep gnused ];

    text = ''
      # Extract web-app-hub apps into Nix modules
      set -euo pipefail

      SCRIPT_DIR="''${NIXERATOR_PATH:-$HOME/dev/nix/nixerator}"
      WEBAPP_DIR="$SCRIPT_DIR/modules/apps/webapps"
      DESKTOP_DIR="$HOME/.local/share/applications"
      ICON_DIR="$HOME/.var/app/org.pvermeer.WebAppHub/data/web-app-hub/icons"

      echo "Extracting web apps from web-app-hub..."
      echo "Desktop files: $DESKTOP_DIR"
      echo "Icons: $ICON_DIR"
      echo "Output: $WEBAPP_DIR"
      echo ""

      # Find all web-app-hub desktop files
      count=0
      for desktop_file in "$DESKTOP_DIR"/*wah*.desktop; do
        if [[ ! -f "$desktop_file" ]]; then
          continue
        fi

        # Extract metadata from desktop file
        wah_id=$(grep "^X-WAH-ID=" "$desktop_file" | cut -d= -f2)
        app_name=$(grep "^Name=" "$desktop_file" | head -1 | cut -d= -f2)
        app_name_slug=$(echo "$app_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        desktop_filename=$(basename "$desktop_file")

        echo "Processing: $app_name (ID: $wah_id)"

        # Create app directory
        app_dir="$WEBAPP_DIR/$app_name_slug"
        mkdir -p "$app_dir"

        # Copy icon if it exists
        if [[ -f "$ICON_DIR/$wah_id.png" ]]; then
          cp "$ICON_DIR/$wah_id.png" "$app_dir/icon.png"
          echo "  ✓ Copied icon"
        else
          echo "  ⚠ Warning: Icon not found at $ICON_DIR/$wah_id.png"
        fi

        # Read desktop file content and replace icon path
        desktop_content=$(cat "$desktop_file" | sed "s|^Icon=.*|Icon=\''${./icon.png}|")

        # Generate Nix module
        cat > "$app_dir/default.nix" <<EOF
      # Auto-generated from web-app-hub
      # Original ID: $wah_id
      { lib, pkgs, config, globals, ... }:

      let
        cfg = config.apps.webapps.$app_name_slug;
        username = globals.user.name;
      in
      {
        options = {
          apps.webapps.$app_name_slug.enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable $app_name web app.";
          };
        };

        config = lib.mkIf cfg.enable {
          home-manager.users.\''${username} = {
            home.file.".local/share/applications/$desktop_filename".text = '''
      $desktop_content
            ''';
          };
        };
      }
      EOF

        echo "  ✓ Created module at $app_dir/default.nix"
        echo ""
        count=$((count + 1))
      done

      if [[ $count -eq 0 ]]; then
        echo "No web-app-hub desktop files found!"
        exit 1
      fi

      echo "Successfully extracted $count web apps!"
      echo ""
      echo "Next steps:"
      echo "1. Review the generated modules in $WEBAPP_DIR"
      echo "2. Rebuild your system to apply changes"
      echo "3. Commit the new modules to git"
    '';
  };
in
{
  options = {
    apps.gui.web-app-hub.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Web App Hub for creating progressive web apps.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install web-app-hub flatpak
    services.flatpak.packages = [
      "org.pvermeer.WebAppHub"
    ];

    # Add extraction script to user's PATH
    home-manager.users.${username} = {
      home.packages = [ extract-webapps ];

      # Set environment variable for nixerator path if different from default
      home.sessionVariables = {
        NIXERATOR_PATH = lib.mkDefault "/home/${username}/dev/nix/nixerator";
      };

      # Install custom browser configurations for Helium
      home.file = {
        ".var/app/org.pvermeer.WebAppHub/config/web-app-hub/browsers/helium.yml" = {
          source = ./browsers/helium.yml;
        };
        ".var/app/org.pvermeer.WebAppHub/config/web-app-hub/desktop-files/helium.desktop" = {
          source = ./desktop-files/helium.desktop;
        };
      };
    };
  };
}
