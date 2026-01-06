
{ config, pkgs, lib, ... }:

let
  # Access stylix colors when available
  inherit (config.lib.stylix.colors) base00 base05 base01 base0D base07 base02;

  # Fallback colors if stylix is not configured
  darkBackgroundColor = if config.stylix.enable then "#${base00}" else "#181a1b";
  darkTextColor = if config.stylix.enable then "#${base05}" else "#e8e6e3";
  lightBackgroundColor = if config.stylix.enable then "#${base07}" else "#dcdad7";
  lightTextColor = if config.stylix.enable then "#${base02}" else "#181a1b";

  darkReaderConfig = {
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
pkgs.writeTextFile {
  name = "Dark-Reader-Settings.json";
  text = builtins.toJSON darkReaderConfig;
  destination = "/Dark-Reader-Settings.json";
}
