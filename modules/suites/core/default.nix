{ lib, pkgs, config, globals, username, ... }:

let
  cfg = config.suites.core;
in
{
  options = {
    suites.core.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable core system infrastructure suite with SSH, Flatpak, and essential system tools.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Core system infrastructure
    system.ssh.enable = true;
    system.flatpak.enable = true;
    apps.cli.tailscale.enable = true;

    # Essential system utilities
    environment.systemPackages = with pkgs; [
      wget
      curl
      nerd-fonts.iosevka  # System-wide font with icon glyphs
    ] ++ [
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
        allowedTCPPorts = lib.mkDefault [ 22 ];  # SSH
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
    users.users.${username} = {
      isNormalUser = true;
      description = globals.user.fullName;
      extraGroups = [ "networkmanager" "wheel" ];
      shell = pkgs.${globals.preferences.shell};
    };

     # naughty
    security.sudo.wheelNeedsPassword = false;
  };
}
