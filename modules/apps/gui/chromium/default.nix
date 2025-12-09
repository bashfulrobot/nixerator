{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.gui.chromium;
  username = globals.user.name;
in
{
  options = {
    apps.gui.chromium.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Chromium web browser with productivity extensions.";
    };
  };

  config = lib.mkIf cfg.enable {

    # System packages - WideVine for DRM streaming content
    environment.systemPackages = with pkgs; [
      (chromium.override { enableWideVine = true; })
    ];

    # Chromium configuration
    programs.chromium = {
      enable = true;

      # Extensions from nixcfg reference
      extensions = [
        "aeblfdkhhhdcdjpifhhbdiojplfjncoa"  # 1Password
        "eimadpbcbfnmbkopoojfekhnkhdbieeh"  # Dark Reader
        "glnpjglilkicbckjpbgcfkogebgllemb"  # Okta
        "kbfnbcaeplbcioakkpcpgfkobkghlhen"  # Grammarly
        "pbmlfaiicoikhdbjagjbglnbfcbcojpj"  # Simplify
        "jldhpllghnbhlbpcmnajkpdmadaolakh"  # Todoist
        "oeopbcgkkoapgobdbedcemjljbihmemj"  # Checker Plus for Mail
        "hkhggnncdpfibdhinjiegagmopldibha"  # Checker Plus for Cal
        "ghbmnnjooekpmoecnnnilnnbdlolhkhi"  # Google Docs Offline
        "pcmpcfapbekmbjjkdalcgopdkipoggdi"  # Markdown downloader
        "bcelhaineggdgbddincjkdmokbbdhgch"  # Mail message URL
        "miancenhdlkbmjmhlginhaaepbdnlllc"  # Copy to clipboard
        "jpfpebmajhhopeonhlcgidhclcccjcik"  # Speed dial
        "ldgfbffkinooeloadekpmfoklnobpien"  # Raindrop
        "bgnkhhnnamicmpeenaelnjfhikgbkllg"  # AdGuard AdBlocker
      ];
    };

    # Home Manager user configuration
    home-manager.users.${username} = {

      programs.chromium = {
        enable = true;

        # Basic Wayland support
        commandLineArgs = [
          "--enable-features=UseOzonePlatform"
          "--ozone-platform=wayland"
          "--enable-features=VaapiVideoDecoder"
          "--enable-gpu-rasterization"
        ];
      };

      # Wayland flags and Dark Reader configuration
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

          # Access stylix colors when available for Dark Reader
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
        {
          # Wayland flags for Chromium and Electron apps
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

          # Dark Reader configuration using Stylix colors
          ".config/darkreader/Dark-Reader-Settings.json".text = builtins.toJSON {
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
                lightSchemeBackgroundColor = lightBackgroundColor;
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
