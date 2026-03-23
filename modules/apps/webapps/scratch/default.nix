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
  name = "scratch";
  displayName = "Scratch";
  url = "https://app.grammarly.com/ddocs/2012354385";
  wmClass = "chrome-app.grammarly.com__ddocs_2012354385-Default";
  icon = ./icon.svg;
}
