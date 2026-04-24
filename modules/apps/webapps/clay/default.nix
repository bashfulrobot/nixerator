{
  lib,
  config,
  globals,
  ...
}:
let
  mkWebApp = import ../../../../lib/mkWebApp.nix { inherit lib; };
in
mkWebApp {
  inherit config globals;
  name = "clay";
  displayName = "Clay";
  url = "https://192.168.169.2:3131/";
  wmClass = "chrome-192.168.169.2__3131-Default";
  icon = ./icon.png;
  iconGlyph = "󰚩";
}
