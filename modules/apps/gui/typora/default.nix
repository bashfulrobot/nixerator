{ pkgs, config, lib, globals, ... }:

let
  cfg = config.apps.gui.typora;
  username = globals.user.name;
in
{
  options = {
    apps.gui.typora.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Typora markdown editor.";
    };

    apps.gui.typora.nautilusIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Add 'Open in Typora' to Nautilus right-click context menu.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      typora
    ] ++ lib.optionals cfg.nautilusIntegration [
      nautilus-python
    ];

    home-manager.users.${username} = {
      home.file = lib.mkIf cfg.nautilusIntegration {
        ".local/share/nautilus-python/extensions/typora-open.py".text = ''
          from gi.repository import Nautilus, GObject
          from subprocess import call
          import os

          class TyporaExtension(GObject.GObject, Nautilus.MenuProvider):
              def launch_typora(self, menu, files):
                  safepaths = ""
                  for file in files:
                      filepath = file.get_location().get_path()
                      safepaths += '"' + filepath + '" '
                  call("typora " + safepaths + "&", shell=True)

              def get_file_items(self, *args):
                  files = args[-1]
                  item = Nautilus.MenuItem(
                      name="TyporaOpen",
                      label="Open in Typora",
                      tip="Opens the selected files with Typora"
                  )
                  item.connect("activate", self.launch_typora, files)
                  return [item]

              def get_background_items(self, *args):
                  file_ = args[-1]
                  item = Nautilus.MenuItem(
                      name="TyporaOpenBackground",
                      label="Open in Typora",
                      tip="Opens the current directory in Typora"
                  )
                  item.connect("activate", self.launch_typora, [file_])
                  return [item]
        '';
      };
    };
  };
}
