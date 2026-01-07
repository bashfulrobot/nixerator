{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.gui.google-chrome;
  username = globals.user.name;

  # Generate Dark Reader configuration with Stylix colors
  mkDarkReaderConfig = stylixConfig:
    let
      # Access stylix colors when available
      inherit (stylixConfig.lib.stylix.colors) base00 base05 base07 base02;

      # Fallback colors if stylix is not configured
      darkBackgroundColor = if stylixConfig.stylix.enable then "#${base00}" else "#181a1b";
      darkTextColor = if stylixConfig.stylix.enable then "#${base05}" else "#e8e6e3";
      lightBackgroundColor = if stylixConfig.stylix.enable then "#${base07}" else "#dcdad7";
      lightTextColor = if stylixConfig.stylix.enable then "#${base02}" else "#181a1b";
    in
    builtins.toJSON {
      automation = {
        behavior = "OnOff";
        enabled = true;
        mode = "system";
      };
      changeBrowserTheme = false;
      customThemes = [
        {
          theme = {
            mode = 0;
            brightness = 80;
            contrast = 100;
            grayscale = 0;
            sepia = 0;
            useFont = false;
            fontFamily = "Open Sans";
            textStroke = 0;
            engine = "dynamicTheme";
            stylesheet = "";
            darkSchemeBackgroundColor = darkBackgroundColor;
            darkSchemeTextColor = darkTextColor;
            lightSchemeBackgroundColor = lightBackgroundColor;
            lightSchemeTextColor = lightTextColor;
            scrollbarColor = "auto";
            selectionColor = "auto";
            styleSystemControls = true;
            lightColorScheme = "Default";
            darkColorScheme = "Default";
            immediateModify = false;
          };
          url = [ "us2.app.sysdig.com" ];
        }
        {
          theme = {
            mode = 1;
            brightness = 100;
            contrast = 100;
            grayscale = 0;
            sepia = 0;
            useFont = false;
            fontFamily = "Open Sans";
            textStroke = 0;
            engine = "dynamicTheme";
            stylesheet = "";
            darkSchemeBackgroundColor = darkBackgroundColor;
            darkSchemeTextColor = darkTextColor;
            lightSchemeBackgroundColor = lightBackgroundColor;
            lightSchemeTextColor = lightTextColor;
            scrollbarColor = "auto";
            selectionColor = "auto";
            styleSystemControls = true;
            lightColorScheme = "Default";
            darkColorScheme = "Default";
            immediateModify = false;
          };
          url = [ "calendar.google.com" ];
        }
      ];
      detectDarkTheme = false;
      disabledFor = [];
      enableContextMenus = true;
      enableForPDF = true;
      enableForProtectedPages = false;
      enabled = true;
      enabledByDefault = true;
      enabledFor = [];
      fetchNews = true;
      location = {
        latitude = null;
        longitude = null;
      };
      presets = [];
      previewNewDesign = false;
      previewNewestDesign = false;
      schemeVersion = 2;
      syncSettings = true;
      syncSitesFixes = true;
      theme = {
        mode = 1;
        brightness = 100;
        contrast = 100;
        grayscale = 0;
        sepia = 0;
        useFont = false;
        fontFamily = "Open Sans";
        textStroke = 0;
        engine = "dynamicTheme";
        stylesheet = "";
        darkSchemeBackgroundColor = darkBackgroundColor;
        darkSchemeTextColor = darkTextColor;
        lightSchemeBackgroundColor = lightBackgroundColor;
        lightSchemeTextColor = lightTextColor;
        scrollbarColor = "auto";
        selectionColor = "auto";
        styleSystemControls = true;
        lightColorScheme = "Default";
        darkColorScheme = "Default";
        immediateModify = false;
      };
      time = {
        activation = "18:00";
        deactivation = "9:00";
      };
    };
in
{
  options = {
    apps.gui.google-chrome.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Google Chrome web browser.";
    };
  };

  config = lib.mkIf cfg.enable {

    # System packages
    environment.systemPackages = with pkgs; [
      google-chrome
    ];

    # Home Manager user configuration
    home-manager.users.${username} = {

      # Wayland flags for Chrome
      home.file =
        let
          waylandFlags = ''
            --enable-features=UseOzonePlatform
            --ozone-platform=wayland
            --enable-features=WaylandWindowDecorations
            --ozone-platform-hint=wayland
            --gtk-version=4
            --enable-features=VaapiVideoDecoder
            --enable-gpu-rasterization
          '';
        in
        {
          ".config/chrome-flags.conf".text = waylandFlags;

          # Dark Reader settings using Stylix colors
          ".config/darkreader/settings.json".text = mkDarkReaderConfig config;
        };

    };

  };
}
