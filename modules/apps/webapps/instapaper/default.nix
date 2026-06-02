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
  name = "instapaper";
  displayName = "Instapaper";
  url = "https://www.instapaper.com/u";
  wmClass = "chrome-www.instapaper.com__u-Default";
  icon = ./icon.png;
  categories = [
    "Network"
    "News"
  ];
}
