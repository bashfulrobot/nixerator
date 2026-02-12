{
  globals,
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.gui.vocalinux;
  username = globals.user.name;
  homeDir = "/home/${username}";
  vocalinux = pkgs.callPackage ./build {
    inherit versions;
    inherit (pkgs) python3Packages;
  };

  # Generate config.json with VOSK defaults
  configJson = pkgs.writeText "config.json" (
    builtins.toJSON {
      engine = "vosk";
      model_path = "${homeDir}/.local/share/vocalinux/models/vosk-model-small-en-us-0.15";
      activation_key = "ctrl";
      double_tap_threshold = 0.3;
      audio = {
        sample_rate = 16000;
        channels = 1;
      };
      ui = {
        show_notification = true;
        show_tray_icon = true;
      };
    }
  );

in
{
  options = {
    apps.gui.vocalinux.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable vocalinux - voice dictation system for Linux with VOSK offline recognition.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ vocalinux ];

    home-manager.users.${username} = {
      # Create config file
      xdg.configFile."vocalinux/config.json".source = configJson;

      # Create models directory structure
      home.file.".local/share/vocalinux/models/.keep".text = "";

      # Add note about model download
      home.file.".local/share/vocalinux/README.txt".text = ''
        Vocalinux requires a VOSK model to work offline.

        On first run, vocalinux will prompt you to download a model, or you can
        manually download the VOSK small English model:

          curl -L https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip \
            -o /tmp/vosk-model.zip
          unzip /tmp/vosk-model.zip -d ~/.local/share/vocalinux/models/

        For other languages or larger models, visit:
          https://alphacephei.com/vosk/models
      '';
    };
  };
}
