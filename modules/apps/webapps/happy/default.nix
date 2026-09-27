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
  name = "happy";
  displayName = "Happy";
  url = "https://app.happy.engineering";
  # Verified on qbert, 2026-09-26 via hyprctl clients -j per .claude/docs/webapps.md.
  wmClass = "chrome-app.happy.engineering__-Default";
  icon = ./icon.png;
  categories = [
    "Network"
    "Development"
  ];
}
