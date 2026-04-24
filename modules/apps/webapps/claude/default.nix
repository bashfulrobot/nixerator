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
  name = "claude";
  displayName = "Claude";
  url = "https://claude.ai/new";
  wmClass = "chrome-claude.ai__new-claude";
  icon = ./icon.png;
  iconGlyph = "󰚩";
  extraArgs = "--user-data-dir=${globals.user.homeDirectory}/.config/google-chrome-claude";
}
