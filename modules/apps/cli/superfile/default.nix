{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.cli.superfile;
  username = globals.user.name;
  inherit (config.lib.stylix) colors;
in
{
  options = {
    apps.cli.superfile.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable superfile with custom theme and hotkeys.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Home Manager user configuration
    home-manager.users.${username} = {
      programs.superfile = {
        enable = true;
        firstUseCheck = false;

        # Integrate with zoxide for smart directory jumping
        zoxidePackage = pkgs.zoxide;

        # Custom hotkeys
        hotkeys = {
          # Navigation
          quit = "q";
          list_up = "k";
          list_down = "j";
          page_up = "K";
          page_down = "J";
          parent_directory = "h";
          open_file = "l";
          go_to_home = "~";
          go_to_root = "/";

          # File operations
          create_new_file = "n";
          create_new_folder = "N";
          delete = "d";
          rename = "r";
          copy = "y";
          paste = "p";
          cut = "x";
          select = "space";
          select_all = "A";

          # View options
          toggle_hidden = ".";
          toggle_preview = "P";

          # Search and jump
          search = "/";
          zoxide_jump = "z";
        };

        # Pinned folders for quick access
        pinnedFolders = [
          {
            name = "Home";
            location = "/home/${username}";
          }
          {
            name = "Projects";
            location = "/home/${username}/dev";
          }
          {
            name = "Nix Config";
            location = "/home/${username}/dev/nix/nixerator";
          }
        ];

        # Custom settings
        settings = {
          # File list settings
          file_size_use_si = true;
          default_open_file_preview = true;

          # Performance
          metadata_update_time = 100;

          # Display
          border_top = true;
          border_bottom = true;
          border_left = true;
          border_right = true;
        };

        # Custom theme using stylix colors
        themes = {
          custom = {
            # File/folder colors
            file_color = "#${colors.base05}";          # normal text
            folder_color = "#${colors.base0D}";        # blue (folders)
            executable_color = "#${colors.base0B}";    # green (executable)
            symlink_color = "#${colors.base0C}";       # cyan (symlink)

            # UI elements
            border_color = "#${colors.base02}";        # subtle border
            cursor_color = "#${colors.base08}";        # red (attention)
            selected_color = "#${colors.base0A}";      # yellow (selected)

            # Sidebar
            sidebar_title_color = "#${colors.base0D}"; # blue (accent)
            sidebar_item_color = "#${colors.base05}";  # normal text
            sidebar_selected_color = "#${colors.base08}"; # red (active)

            # Modal/dialog
            modal_border_color = "#${colors.base03}";  # lighter border
            modal_title_color = "#${colors.base0D}";   # blue (accent)
            modal_content_color = "#${colors.base05}"; # normal text

            # Footer/status bar
            footer_background_color = "#${colors.base00}"; # base background
            footer_text_color = "#${colors.base05}";   # normal text

            # File preview
            preview_border_color = "#${colors.base02}"; # subtle border
            preview_title_color = "#${colors.base0D}";  # blue (accent)
            preview_text_color = "#${colors.base05}";   # normal text
          };
        };
      };
    };
  };
}
