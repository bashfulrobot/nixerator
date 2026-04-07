{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.suites.core;
in
{
  options = {
    suites.core.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable core system infrastructure suite with SSH, Flatpak, GNOME Online Accounts (Google Drive), Web App Hub, backup tools (restic), and essential system tools.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Core system infrastructure
    system = {
      ssh.enable = true;
      flatpak.enable = true;
      gnome-online-accounts.enable = true;
    };
    apps = {
      cli = {
        tailscale.enable = true;
        cpx.enable = true;
        gws.enable = true;
        restic.enable = true;
      };
      gui.web-app-hub.enable = true;
    };

    # Automatic timezone detection based on geolocation
    services.automatic-timezoned.enable = true;

    # Remap Caps Lock to Scroll Lock (Voxtype push-to-talk hotkey)
    services.keyd = {
      enable = true;
      keyboards.default.settings = {
        main = {
          capslock = "scrolllock";
        };
      };
    };

    # Essential system utilities
    environment.systemPackages =
      with pkgs;
      [
        comma
        gnome-disk-utility
        gnome-system-monitor
        nautilus-python
        wget
        curl
        nerd-fonts.iosevka # System-wide font with icon glyphs
      ]
      ++ [
        # Desktop entry for rebooting to firmware (UEFI/BIOS setup)
        (pkgs.makeDesktopItem {
          name = "reboot-firmware";
          desktopName = "Reboot to Firmware";
          comment = "Reboot the computer and enter firmware (UEFI/BIOS) setup";
          exec = "${pkgs.systemd}/bin/systemctl reboot --firmware-setup";
          icon = "system-reboot";
          terminal = false;
          type = "Application";
          categories = [ "System" ];
        })
      ];

    # Networking defaults
    networking = {
      networkmanager.enable = lib.mkDefault true;
      firewall = {
        enable = lib.mkDefault true;
        allowedTCPPorts = lib.mkDefault [ 22 ]; # SSH
      };
    };

    # Locale configuration from globals
    i18n.extraLocaleSettings = {
      LC_ADDRESS = globals.defaults.locale;
      LC_IDENTIFICATION = globals.defaults.locale;
      LC_MEASUREMENT = globals.defaults.locale;
      LC_MONETARY = globals.defaults.locale;
      LC_NAME = globals.defaults.locale;
      LC_NUMERIC = globals.defaults.locale;
      LC_PAPER = globals.defaults.locale;
      LC_TELEPHONE = globals.defaults.locale;
      LC_TIME = globals.defaults.locale;
    };

    # User configuration
    users.users.${globals.user.name} = {
      isNormalUser = true;
      description = globals.user.fullName;
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      shell = pkgs.${globals.preferences.shell};
    };

    # Nautilus right-click "Copy Path" extension (top-level context menu)
    home-manager.users.${globals.user.name} = {
      home.file.".local/share/nautilus-python/extensions/copy-path.py".text = ''
        from gi.repository import Nautilus, GObject
        from subprocess import Popen, PIPE

        class CopyPathExtension(GObject.GObject, Nautilus.MenuProvider):
            def copy_paths(self, menu, files):
                paths = "\n".join(f.get_location().get_path() for f in files if f.get_location().get_path())
                Popen(["wl-copy"], stdin=PIPE).communicate(paths.encode())

            def get_file_items(self, *args):
                files = args[-1]
                item = Nautilus.MenuItem(
                    name="CopyPath",
                    label="Copy Path",
                    tip="Copy the selected file path(s) to clipboard"
                )
                item.connect("activate", self.copy_paths, files)
                return [item]

            def get_background_items(self, *args):
                file_ = args[-1]
                item = Nautilus.MenuItem(
                    name="CopyPathBackground",
                    label="Copy Path",
                    tip="Copy the current directory path to clipboard"
                )
                item.connect("activate", self.copy_paths, [file_])
                return [item]
      '';
    };

    # naughty
    security.sudo.wheelNeedsPassword = false;
  };
}
