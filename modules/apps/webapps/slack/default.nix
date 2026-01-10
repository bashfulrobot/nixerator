# Auto-generated from web-app-hub
# Original ID: pkKAOnyO
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.webapps.slack;
  username = globals.user.name;
in
{
  options = {
    apps.webapps.slack.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Slack web app.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      home.file.".local/share/applications/com.google.Chrome.chrome-wah-pkKAOnyO.desktop".text = ''
[Desktop Entry]
Exec=google-chrome-stable --no-first-run --app="https://app.slack.com/client/T0DS5NB27" --class=chrome-app.slack.com__client_T0DS5NB27-Default --name=chrome-app.slack.com__client_T0DS5NB27-Default  
Icon=${./icon.png}
Name=Slack
StartupWMClass=chrome-app.slack.com__client_T0DS5NB27-Default
Terminal=false
Type=Application
Version=1.0
X-MultipleArgs=false
X-WAH=true
X-WAH-BROWSER-ID=google-chrome-stable
X-WAH-ID=pkKAOnyO
X-WAH-ISOLATE=false
X-WAH-MAXIMIZE=false
X-WAH-PROFILE=
X-WAH-URL=https://app.slack.com/client/T0DS5NB27
X-WAH-VERSION=0.1.2
      '';
    };
  };
}
