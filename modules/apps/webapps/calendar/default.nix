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
  name = "calendar";
  displayName = "Calendar";
  url = "https://calendar.google.com/calendar/u/1/r";
  wmClass = "chrome-calendar.google.com__calendar_u_1_r-Default";
  icon = ./icon.png;
}
