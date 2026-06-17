{
  globals,
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.fresh-editor;

  # Stylix palette (base16). Always present, like the vscode/google-chrome
  # modules; the generated theme is only wired in when Stylix is enabled.
  inherit (config.lib.stylix) colors;
  stylixEnabled = config.stylix.enable;

  # fresh themes take [r,g,b] integer triples. base16.nix exposes each slot's
  # decimal channels as strings (e.g. colors."base00-rgb-r"), so convert here.
  mkRGB =
    name:
    map lib.toInt [
      colors."${name}-rgb-r"
      colors."${name}-rgb-g"
      colors."${name}-rgb-b"
    ];

  # base16 -> fresh theme. Whole sections we omit inherit from `extends`; the
  # leaves we set below override it. Mapping follows base16 conventions
  # (base08=red .. base0F=brown). Schema: sinelaw/fresh theme.schema.json.
  freshStylixTheme = {
    name = "stylix";
    extends = if (config.stylix.polarity or "dark") == "light" then "light" else "dark";

    editor = {
      bg = mkRGB "base00";
      fg = mkRGB "base05";
      cursor = mkRGB "base0D";
      selection_bg = mkRGB "base02";
      current_line_bg = mkRGB "base01";
      line_number_fg = mkRGB "base03";
      line_number_bg = mkRGB "base00";
      ruler_bg = mkRGB "base01";
      whitespace_indicator_fg = mkRGB "base03";
      bracket_match_fg = mkRGB "base0A";
    };

    syntax = {
      keyword = mkRGB "base0E"; # magenta
      string = mkRGB "base0B"; # green
      comment = mkRGB "base03"; # muted
      function = mkRGB "base0D"; # blue
      type = mkRGB "base0A"; # yellow
      variable = mkRGB "base05"; # default fg
      variable_builtin = mkRGB "base08"; # red
      constant = mkRGB "base09"; # orange
      operator = mkRGB "base0C"; # cyan
      punctuation_bracket = mkRGB "base05";
      punctuation_delimiter = mkRGB "base05";
    };

    ui = {
      status_bar_bg = mkRGB "base01";
      status_bar_fg = mkRGB "base04";
      tab_active_bg = mkRGB "base00";
      tab_active_fg = mkRGB "base05";
      tab_inactive_bg = mkRGB "base01";
      tab_inactive_fg = mkRGB "base04";
      menu_bg = mkRGB "base01";
      menu_fg = mkRGB "base05";
      popup_bg = mkRGB "base01";
      terminal_bg = mkRGB "base00";
      terminal_fg = mkRGB "base05";
    };

    diagnostic = {
      error_fg = mkRGB "base08";
      warning_fg = mkRGB "base0A";
      info_fg = mkRGB "base0D";
      hint_fg = mkRGB "base0C";
    };

    search = {
      match_bg = mkRGB "base0A";
      match_fg = mkRGB "base00";
    };
  };
in
{
  options = {
    apps.cli.fresh-editor.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the fresh terminal editor (LSP-capable, github.com/sinelaw/fresh).";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      programs.fresh-editor = {
        enable = true;
        package = pkgs.fresh-editor;

        # Left to helix in the dev suite, which owns EDITOR/VISUAL. fresh is
        # launched explicitly via `fresh`; flip this if it should win instead.
        defaultEditor = false;

        # LSP servers / formatters are wrapped onto fresh's PATH. This repo is
        # a Nix config, so nixd + nixfmt ship by default; add more as needed.
        extraPackages = with pkgs; [
          nixd
          nixfmt
        ];

        # Schema: github.com/sinelaw/fresh config-schema.json
        settings = {
          version = 1;

          # Stylix-generated theme when themed; the built-in "dark" otherwise.
          theme = if stylixEnabled then "stylix.json" else "dark";

          # Default is true, which also sends anonymous telemetry (version, OS,
          # terminal type) on startup. Disabled here.
          check_for_updates = false;

          editor = {
            line_numbers = true;
            relative_line_numbers = true;
            highlight_current_line = true;
            highlight_matching_brackets = true;
            rainbow_brackets = true;
            scroll_offset = 5;
            rulers = [ 80 ];
            trim_trailing_whitespace_on_save = true;
            ensure_final_newline_on_save = true;
          };

          clipboard = {
            # OSC 52 lets yank/paste cross SSH and multiplexers cleanly.
            use_osc52 = true;
            use_system_clipboard = true;
          };

          lsp = {
            nix = [
              {
                command = "nixd";
                auto_start = true;
              }
            ];
          };

          languages = {
            nix = {
              format_on_save = true;
              formatter.command = "nixfmt";
            };
          };
        };
      };

      # User theme dir is scanned by fresh; reference it as "stylix.json"
      # (relative paths resolve against ~/.config/fresh/themes/).
      xdg.configFile."fresh/themes/stylix.json" = lib.mkIf stylixEnabled {
        text = builtins.toJSON freshStylixTheme;
      };
    };
  };
}
