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
  name = "kong-docs";
  displayName = "Kong Docs";
  url = "https://developer.konghq.com/";
  wmClass = "chrome-developer.konghq.com__-Default";
  icon = ./icon.png;
  iconGlyph = "󰂺";
}
