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
  vocalinux = pkgs.callPackage ./build {
    inherit versions;
    inherit (pkgs) python3Packages;
  };
  voskModel = import ./build/vosk-model.nix { inherit pkgs versions; };

  configJson = pkgs.writeText "config.json" (
    builtins.toJSON {
      speech_recognition = {
        engine = "vosk";
        language = "auto";
        vosk_model_size = "small";
        whisper_model_size = "tiny";
        vad_sensitivity = 3;
        silence_timeout = 2.0;
      };
      audio = {
        device_index = null;
        device_name = null;
      };
      shortcuts = {
        toggle_recognition = "ctrl+ctrl";
      };
      ui = {
        start_minimized = false;
        show_notifications = true;
      };
      advanced = {
        debug_logging = false;
        wayland_mode = false;
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

    # uinput access for virtual keyboard input
    users.users."${username}".extraGroups = [ "input" ];
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660"
    '';

    home-manager.users.${username} = {
      xdg.configFile."vocalinux/config.json".source = configJson;

      # Symlink VOSK model into the location the app expects
      home.file.".local/share/vocalinux/models/vosk-model-small-en-us-0.15".source = voskModel;
    };
  };
}
