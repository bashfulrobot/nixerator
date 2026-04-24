{ lib }:

{ config
, globals
, name
, displayName
, url
, wmClass
, icon
, categories ? [ "Network" ]
, mimeTypes ? [ ]
, defaultFor ? { }
, extraArgs ? ""
, iconGlyph ? null
,
}:

let
  cfg = config.apps.webapps.${name};
  inherit (globals.preferences) browser;
  desktopName = "${name}-webapp";
  # Escape % as %% for desktop entry field code validation
  escapedUrl = builtins.replaceStrings [ "%" ] [ "%%" ] url;
  execLine =
    ''${browser} --no-first-run --new-instance --app="${escapedUrl}" --class=${wmClass} --name=${wmClass} --wayland-text-input-version=3''
    + lib.optionalString (extraArgs != "") " ${extraArgs}"
    + " %u";
in
{
  options.apps.webapps.${name}.enable = lib.mkEnableOption "${displayName} web app";

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home-manager.users.${globals.user.name} = {
        xdg.desktopEntries.${desktopName} = {
          name = displayName;
          exec = execLine;
          icon = "${icon}";
          terminal = false;
          type = "Application";
          inherit categories;
          startupNotify = true;
          mimeType = mimeTypes;
          settings = {
            StartupWMClass = wmClass;
          };
        };

        xdg.mimeApps.defaultApplications = defaultFor;
      };
    }
    (lib.mkIf (iconGlyph != null) {
      hyprflake.desktop.waybar.workspaceAppIcons.rewrites."class<${wmClass}>" = iconGlyph;
    })
  ]);
}
