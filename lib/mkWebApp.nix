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
  browser = globals.preferences.browser;
  desktopName = "${name}-webapp";
  # Escape % as %% for desktop entry field code validation
  escapedUrl = builtins.replaceStrings [ "%" ] [ "%%" ] url;
  execLine =
    ''${browser} --no-first-run --app="${escapedUrl}" --class=${wmClass} --name=${wmClass}''
    + lib.optionalString (extraArgs != "") " ${extraArgs}";
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

      xdg.mimeApps.defaultApplications = defaultFor;
    };
  };
}
