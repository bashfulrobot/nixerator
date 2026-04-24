{ lib
, config
, globals
, ...
}:
let
  mkWebApp = import ../../../../lib/mkWebApp.nix { inherit lib; };
in
mkWebApp {
  inherit config globals;
  name = "zoom";
  displayName = "Zoom";
  url = "https://app.zoom.us/wc/home";
  wmClass = "chrome-app.zoom.us__wc_home-Default";
  icon = ./icon.png;
  iconGlyph = "󰕧";
  categories = [
    "Network"
    "VideoConference"
  ];
  mimeTypes = [ "x-scheme-handler/zoommtg" ];
  defaultFor = {
    "x-scheme-handler/zoommtg" = [ "zoom-webapp.desktop" ];
  };
}
