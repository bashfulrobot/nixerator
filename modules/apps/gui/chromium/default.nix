{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.gui.chromium;
  username = globals.user.name;
in
{
  options = {
    apps.gui.chromium = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Chromium web browser with extensions and configuration.";
      };

      setAsDefault = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Set Chromium as the default browser";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    # System packages
    environment.systemPackages = with pkgs; [
      (chromium.override { enableWideVine = true; })  # DRM support for streaming
    ];

    # Chromium configuration
    programs.chromium = {
      enable = true;

      extensions = [
        # 1Password
        "aeblfdkhhhdcdjpifhhbdiojplfjncoa"
        # Dark Reader
        "eimadpbcbfnmbkopoojfekhnkhdbieeh"
        # Okta
        "glnpjglilkicbckjpbgcfkogebgllemb"
        # Grammarly
        "kbfnbcaeplbcioakkpcpgfkobkghlhen"
        # Simplify
        "pbmlfaiicoikhdbjagjbglnbfcbcojpj"
        # Todoist
        "jldhpllghnbhlbpcmnajkpdmadaolakh"
        # Checker Plus for Mail
        "oeopbcgkkoapgobdbedcemjljbihmemj"
        # Checker Plus for Cal
        "hkhggnncdpfibdhinjiegagmopldibha"
        # Google Docs Offline
        "ghbmnnjooekpmoecnnnilnnbdlolhkhi"
        # Markdown downloader
        "pcmpcfapbekmbjjkdalcgopdkipoggdi"
        # Mail message URL
        "bcelhaineggdgbddincjkdmokbbdhgch"
        # Copy to clipboard
        "miancenhdlkbmjmhlginhaaepbdnlllc"
        # Speed dial
        "jpfpebmajhhopeonhlcgidhclcccjcik"
        # Raindrop
        "ldgfbffkinooeloadekpmfoklnobpien"
        # AdGuard AdBlocker
        "bgnkhhnnamicmpeenaelnjfhikgbkllg"
      ];
    };

    # Home Manager user configuration
    home-manager.users.${username} = {

      # Set as default browser
      home.sessionVariables = lib.mkIf cfg.setAsDefault {
        BROWSER = "chromium";
      };

      xdg.mimeApps = lib.mkIf cfg.setAsDefault {
        enable = true;
        defaultApplications = {
          "text/html" = [ "chromium.desktop" ];
          "x-scheme-handler/http" = [ "chromium.desktop" ];
          "x-scheme-handler/https" = [ "chromium.desktop" ];
          "x-scheme-handler/about" = [ "chromium.desktop" ];
          "x-scheme-handler/unknown" = [ "chromium.desktop" ];
          "applications/x-www-browser" = [ "chromium.desktop" ];
        };
      };

      # Wayland flags for Chromium and Electron apps
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
          ".config/chromium-flags.conf".text = waylandFlags;
          ".config/electron-flags.conf".text = waylandFlags;
          ".config/electron-flags16.conf".text = waylandFlags;
          ".config/electron-flags17.conf".text = waylandFlags;
          ".config/electron-flags18.conf".text = waylandFlags;
          ".config/electron-flags19.conf".text = waylandFlags;
          ".config/electron-flags20.conf".text = waylandFlags;
          ".config/electron-flags21.conf".text = waylandFlags;
          ".config/electron-flags22.conf".text = waylandFlags;
          ".config/electron-flags23.conf".text = waylandFlags;
          ".config/electron-flags24.conf".text = waylandFlags;
          ".config/electron-flags25.conf".text = waylandFlags;

          # Dark Reader configuration using stylix colors
          ".config/darkreader/Dark-Reader-Settings.json".text =
            let
              # Access stylix colors when available
              inherit (config.lib.stylix.colors) base00 base05 base01 base0D base07 base02;

              # Fallback colors if stylix is not configured
              backgroundColor = if config.stylix.enable then "#${base00}" else "#1e1e2e";
              textColor = if config.stylix.enable then "#${base05}" else "#cdd6f4";
              surfaceColor = if config.stylix.enable then "#${base01}" else "#313244";
              accentColor = if config.stylix.enable then "#${base0D}" else "#89b4fa";
              lightBackgroundColor = if config.stylix.enable then "#${base07}" else "#eff1f5";
              lightTextColor = if config.stylix.enable then "#${base02}" else "#4c4f69";
              fontFamily = if config.stylix.enable then config.stylix.fonts.monospace.name else "Iosevka Nerd Font";
            in
            builtins.toJSON {
              schemeVersion = 2;
              enabled = true;
              fetchNews = true;
              theme = {
                mode = 1; # Dark mode
                brightness = 100;
                contrast = 100;
                grayscale = 0;
                sepia = 0;
                useFont = false;
                fontFamily = fontFamily;
                textStroke = 0;
                engine = "dynamicTheme";
                stylesheet = "";
                darkSchemeBackgroundColor = backgroundColor;
                darkSchemeTextColor = textColor;
                lightSchemeBackgroundColor = lightBackgroundColor;
                lightSchemeTextColor = lightTextColor;
                scrollbarColor = surfaceColor;
                selectionColor = accentColor;
                styleSystemControls = true;
                lightColorScheme = "Default";
                darkColorScheme = "Default";
                immediateModify = false;
              };
              presets = [];
              customThemes = [
                # Office 365
                {
                  builtIn = true;
                  theme = {
                    mode = 1;
                    brightness = 100;
                    contrast = 100;
                    grayscale = 0;
                    sepia = 0;
                    useFont = false;
                    fontFamily = fontFamily;
                    textStroke = 0;
                    engine = "cssFilter";
                    stylesheet = "";
                    darkSchemeBackgroundColor = backgroundColor;
                    darkSchemeTextColor = textColor;
                    lightSchemeBackgroundColor = lightBackgroundColor;
                    lightSchemeTextColor = lightTextColor;
                    scrollbarColor = surfaceColor;
                    selectionColor = accentColor;
                    styleSystemControls = true;
                    lightColorScheme = "Default";
                    darkColorScheme = "Default";
                    immediateModify = false;
                  };
                  url = [ "*.officeapps.live.com" ];
                }
                # SharePoint
                {
                  builtIn = true;
                  theme = {
                    mode = 1;
                    brightness = 100;
                    contrast = 100;
                    grayscale = 0;
                    sepia = 0;
                    useFont = false;
                    fontFamily = fontFamily;
                    textStroke = 0;
                    engine = "cssFilter";
                    stylesheet = "";
                    darkSchemeBackgroundColor = backgroundColor;
                    darkSchemeTextColor = textColor;
                    lightSchemeBackgroundColor = lightBackgroundColor;
                    lightSchemeTextColor = lightTextColor;
                    scrollbarColor = surfaceColor;
                    selectionColor = accentColor;
                    styleSystemControls = true;
                    lightColorScheme = "Default";
                    darkColorScheme = "Default";
                    immediateModify = false;
                  };
                  url = [ "*.sharepoint.com" ];
                }
                # Google Docs
                {
                  builtIn = true;
                  theme = {
                    mode = 1;
                    brightness = 100;
                    contrast = 100;
                    grayscale = 0;
                    sepia = 0;
                    useFont = false;
                    fontFamily = fontFamily;
                    textStroke = 0;
                    engine = "cssFilter";
                    stylesheet = "";
                    darkSchemeBackgroundColor = backgroundColor;
                    darkSchemeTextColor = textColor;
                    lightBackgroundColor = lightBackgroundColor;
                    lightSchemeTextColor = lightTextColor;
                    scrollbarColor = surfaceColor;
                    selectionColor = accentColor;
                    styleSystemControls = true;
                    lightColorScheme = "Default";
                    darkColorScheme = "Default";
                    immediateModify = false;
                  };
                  url = [ "docs.google.com" ];
                }
                # OneDrive
                {
                  builtIn = true;
                  theme = {
                    mode = 1;
                    brightness = 100;
                    contrast = 100;
                    grayscale = 0;
                    sepia = 0;
                    useFont = false;
                    fontFamily = fontFamily;
                    textStroke = 0;
                    engine = "cssFilter";
                    stylesheet = "";
                    darkSchemeBackgroundColor = backgroundColor;
                    darkSchemeTextColor = textColor;
                    lightSchemeBackgroundColor = lightBackgroundColor;
                    lightSchemeTextColor = lightTextColor;
                    scrollbarColor = surfaceColor;
                    selectionColor = accentColor;
                    styleSystemControls = true;
                    lightColorScheme = "Default";
                    darkColorScheme = "Default";
                    immediateModify = false;
                  };
                  url = [ "onedrive.live.com" ];
                }
              ];
              enabledByDefault = true;
              enabledFor = [];
              disabledFor = [
                "mail.google.com"
                "docs.google.com"
                "www.linkedin.com"
              ];
              changeBrowserTheme = false;
              syncSettings = true;
              syncSitesFixes = false;
              automation = {
                behavior = "OnOff";
                enabled = false;
                mode = "";
              };
              time = {
                activation = "18:00";
                deactivation = "9:00";
              };
              location = {
                latitude = null;
                longitude = null;
              };
              previewNewDesign = false;
              previewNewestDesign = false;
              enableForPDF = true;
              enableForProtectedPages = false;
              enableContextMenus = false;
              detectDarkTheme = true;
              displayedNews = [ "google-docs-bugs" ];
            };
        };
    };
  };
}
