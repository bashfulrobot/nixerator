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
            # Code syntax highlighting
            code_syntax_highlight = "base16";

            # Borders
            file_panel_border = "#${colors.base02}";
            sidebar_border = "#${colors.base01}";
            footer_border = "#${colors.base02}";

            # Border Active
            file_panel_border_active = "#${colors.base0D}";
            sidebar_border_active = "#${colors.base0E}";
            footer_border_active = "#${colors.base0A}";
            modal_border_active = "#${colors.base0D}";

            # Backgrounds
            full_screen_bg = "#${colors.base00}";
            file_panel_bg = "#${colors.base00}";
            sidebar_bg = "#${colors.base00}";
            footer_bg = "#${colors.base00}";
            modal_bg = "#${colors.base00}";

            # Foregrounds
            full_screen_fg = "#${colors.base05}";
            file_panel_fg = "#${colors.base05}";
            sidebar_fg = "#${colors.base05}";
            footer_fg = "#${colors.base05}";
            modal_fg = "#${colors.base05}";

            # Special Colors
            cursor = "#${colors.base0D}";
            correct = "#${colors.base0B}";
            error = "#${colors.base08}";
            hint = "#${colors.base0C}";
            cancel = "#${colors.base03}";
            gradient_color = [ "#${colors.base0D}" "#${colors.base0E}" ];

            # File Panel Special Items
            file_panel_top_directory_icon = "#${colors.base0D}";
            file_panel_top_path = "#${colors.base0A}";
            file_panel_item_selected_fg = "#${colors.base0E}";
            file_panel_item_selected_bg = "#${colors.base01}";

            # Sidebar Special Items
            sidebar_title = "#${colors.base0D}";
            sidebar_item_selected_fg = "#${colors.base0A}";
            sidebar_item_selected_bg = "#${colors.base01}";
            sidebar_divider = "#${colors.base03}";

            # Modal Special Items
            modal_cancel_fg = "#${colors.base05}";
            modal_cancel_bg = "#${colors.base02}";
            modal_confirm_fg = "#${colors.base00}";
            modal_confirm_bg = "#${colors.base0D}";

            # Help Menu
            help_menu_hotkey = "#${colors.base0A}";
            help_menu_title = "#${colors.base0D}";
          };
        };
      };
    };
  };
}
