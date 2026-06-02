{ lib }:

{
  config,
  globals,
  name,
  displayName,
  url,
  wmClass,
  icon,
  categories ? [ "Network" ],
  mimeTypes ? [ ],
  defaultFor ? { },
  extraArgs ? "",
}:

let
  cfg = config.apps.webapps.${name};
  inherit (globals.preferences) browser;
  desktopName = "${name}-webapp";
  manageDesktopName = "${name}-webapp-manage";
  # Per-PWA Chrome profile. Forces a separate Chrome process so PWA app-ids
  # don't leak onto the regular browser's windows under Wayland — without
  # this, every Chrome window ends up sharing one process and Hyprland
  # mis-classes them.
  userDataDir = "${globals.user.homeDirectory}/.config/google-chrome-${name}";
  # Escape % as %% for desktop entry field code validation
  escapedUrl = builtins.replaceStrings [ "%" ] [ "%%" ] url;
  execLine =
    ''${browser} --no-first-run --new-instance --app="${escapedUrl}" --class=${wmClass} --name=${wmClass} --user-data-dir=${userDataDir} --wayland-text-input-version=3''
    + lib.optionalString (extraArgs != "") " ${extraArgs}"
    + " %u";
  # Opens the PWA's profile as a normal browser window (URL bar + extensions
  # toolbar visible) so extensions can be installed and service logins
  # performed. The PWA inherits everything because it shares the user-data-dir.
  manageExecLine = "${browser} --no-first-run --user-data-dir=${userDataDir} --wayland-text-input-version=3";
in
{
  options.apps.webapps.${name}.enable = lib.mkEnableOption "${displayName} web app";

  config = lib.mkIf cfg.enable {
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

      xdg.desktopEntries.${manageDesktopName} = {
        name = "Manage ${displayName}";
        genericName = "Manage ${displayName} extensions and logins";
        exec = manageExecLine;
        icon = "${icon}";
        terminal = false;
        type = "Application";
        categories = [ "Settings" ];
        startupNotify = false;
      };

      xdg.mimeApps.defaultApplications = defaultFor;
    };
  };
}
