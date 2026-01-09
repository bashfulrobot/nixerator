# Auto-generated from web-app-hub
# Original ID: FVFxPpYj
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.webapps.clari;
  username = globals.user.name;
in
{
  options = {
    apps.webapps.clari.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Clari web app.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      home.file.".local/share/applications/com.google.Chrome.chrome-wah-FVFxPpYj.desktop".text = ''
[Desktop Entry]
Exec=google-chrome-stable --no-first-run --app="https://copilot.clari.com/myCalls" --class=chrome-copilot.clari.com__myCalls-Default --name=chrome-copilot.clari.com__myCalls-Default  
Icon=${./icon.png}
Name=Clari
StartupWMClass=chrome-copilot.clari.com__myCalls-Default
Terminal=false
Type=Application
Version=1.0
X-MultipleArgs=false
X-WAH=true
X-WAH-BROWSER-ID=google-chrome-stable
X-WAH-ID=FVFxPpYj
X-WAH-ISOLATE=false
X-WAH-MAXIMIZE=false
X-WAH-PROFILE=
X-WAH-URL=https://copilot.clari.com/myCalls
X-WAH-VERSION=0.1.2
      '';
    };
  };
}
