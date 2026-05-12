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
  name = "salesforce";
  displayName = "Salesforce";
  url = "https://kong.lightning.force.com/lightning/r/Dashboard/01ZPJ000004TcSb2AK/view?queryScope=userFolders";
  wmClass = "chrome-kong.lightning.force.com__lightning_r_Dashboard_01ZPJ000004TcSb2AK_view-Default";
  icon = ./icon.png;
  iconGlyph = "󰢩";
  categories = [
    "Network"
    "Office"
  ];
}
