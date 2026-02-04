{
  config,
  lib,
  pkgs,
  ...
}:

# GNOME Online Accounts Module
# Enables Google Drive (and other cloud services) integration in Nautilus
# outside of the GNOME desktop environment (e.g., Hyprland)
#
# Usage: system.gnome-online-accounts.enable = true;
# Then run "GNOME Online Accounts" from app launcher to add accounts

let
  cfg = config.system.gnome-online-accounts;
in
{
  options.system.gnome-online-accounts = {
    enable = lib.mkEnableOption "GNOME Online Accounts for cloud service integration (Google Drive, etc.)";
  };

  config = lib.mkIf cfg.enable {
    # Core GNOME services required for Online Accounts
    services = {
      accounts-daemon.enable = true;
      gnome = {
        gnome-online-accounts.enable = true;
        evolution-data-server.enable = true;
        gnome-keyring.enable = true;
      };
      # GVFS with full GNOME support (includes Google Drive backend)
      gvfs = {
        enable = true;
        package = pkgs.gnome.gvfs;
      };
    };

    # Required packages
    environment.systemPackages = with pkgs; [
      gnome-online-accounts
      gnome-control-center
      libsecret
      gcr_4

      # Desktop entry for launching GNOME Control Center Online Accounts
      # with the required XDG_CURRENT_DESKTOP=GNOME environment variable
      (pkgs.makeDesktopItem {
        name = "gnome-online-accounts-setup";
        desktopName = "GNOME Online Accounts";
        comment = "Add Google, Microsoft, and other online accounts for Nautilus integration";
        exec = "${pkgs.writeShellScript "goa-setup" ''
          export XDG_CURRENT_DESKTOP=GNOME
          exec ${pkgs.gnome-control-center}/bin/gnome-control-center online-accounts
        ''}";
        icon = "gnome-online-accounts";
        terminal = false;
        type = "Application";
        categories = [ "Settings" "GNOME" "GTK" ];
        keywords = [ "google" "drive" "cloud" "accounts" "online" "microsoft" "onedrive" ];
      })
    ];
  };
}
