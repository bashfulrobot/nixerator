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
  name = "mail";
  displayName = "Mail";
  url = "https://mail.google.com/mail/u/1/#search/is%3Aunread+in%3Ainbox";
  wmClass = "chrome-mail.google.com__mail_u_1_-Default";
  icon = ./icon.png;
  iconGlyph = "󰇮";
}
