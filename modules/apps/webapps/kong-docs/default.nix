# Auto-generated from web-app-hub
# Original ID: mffwTD3t
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.webapps.kong-docs;
  username = globals.user.name;
in
{
  options = {
    apps.webapps.kong-docs.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Kong Docs web app.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      home.file.".local/share/applications/com.google.Chrome.chrome-wah-mffwTD3t.desktop".text = ''
[Desktop Entry]
Exec=google-chrome-stable --no-first-run --app="https://developer.konghq.com/" --class=chrome-developer.konghq.com__-Default --name=chrome-developer.konghq.com__-Default  
Icon=${./icon.png}
Name=Kong Docs
StartupWMClass=chrome-developer.konghq.com__-Default
Terminal=false
Type=Application
Version=1.0
X-MultipleArgs=false
X-WAH=true
X-WAH-BROWSER-ID=google-chrome-stable
X-WAH-ID=mffwTD3t
X-WAH-ISOLATE=false
X-WAH-MAXIMIZE=false
X-WAH-PROFILE=
X-WAH-URL=https://developer.konghq.com/
X-WAH-VERSION=0.1.2
      '';
    };
  };
}
