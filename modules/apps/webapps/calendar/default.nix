# Auto-generated from web-app-hub
# Original ID: Aa1MeSDZ
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.webapps.calendar;
  username = globals.user.name;
in
{
  options = {
    apps.webapps.calendar.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Calendar web app.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      home.file.".local/share/applications/com.google.Chrome.chrome-wah-Aa1MeSDZ.desktop".text = ''
[Desktop Entry]
Exec=google-chrome-stable --no-first-run --app="https://calendar.google.com/calendar/u/1/r" --class=chrome-calendar.google.com__calendar_u_1_r-Default --name=chrome-calendar.google.com__calendar_u_1_r-Default  
Icon=${./icon.png}
Name=Calendar
StartupWMClass=chrome-calendar.google.com__calendar_u_1_r-Default
Terminal=false
Type=Application
Version=1.0
X-MultipleArgs=false
X-WAH=true
X-WAH-BROWSER-ID=google-chrome-stable
X-WAH-ID=Aa1MeSDZ
X-WAH-ISOLATE=false
X-WAH-MAXIMIZE=false
X-WAH-PROFILE=
X-WAH-URL=https://calendar.google.com/calendar/u/1/r
X-WAH-VERSION=0.1.2
      '';
    };
  };
}
