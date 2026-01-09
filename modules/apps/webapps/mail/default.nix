# Auto-generated from web-app-hub
# Original ID: wAz4yPiZ
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.webapps.mail;
  username = globals.user.name;
in
{
  options = {
    apps.webapps.mail.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Mail web app.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      home.file.".local/share/applications/com.google.Chrome.chrome-wah-wAz4yPiZ.desktop".text = ''
[Desktop Entry]
Exec=google-chrome-stable --no-first-run --app="https://mail.google.com/mail/u/1/#search/is%3Aunread+in%3Ainbox" --class=chrome-mail.google.com__mail_u_1_-Default --name=chrome-mail.google.com__mail_u_1_-Default  
Icon=${./icon.png}
Name=Mail
StartupWMClass=chrome-mail.google.com__mail_u_1_-Default
Terminal=false
Type=Application
Version=1.0
X-MultipleArgs=false
X-WAH=true
X-WAH-BROWSER-ID=google-chrome-stable
X-WAH-ID=wAz4yPiZ
X-WAH-ISOLATE=false
X-WAH-MAXIMIZE=false
X-WAH-PROFILE=
X-WAH-URL=https://mail.google.com/mail/u/1/#search/is%3Aunread+in%3Ainbox
X-WAH-VERSION=0.1.2
      '';
    };
  };
}
