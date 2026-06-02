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
  name = "clari";
  displayName = "Clari";
  url = "https://copilot.clari.com/myCalls";
  wmClass = "chrome-copilot.clari.com__myCalls-Default";
  icon = ./icon.png;
}
