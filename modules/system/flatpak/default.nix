{
  config,
  lib,
  inputs,
  ...
}:

# Flatpak Configuration Module
# Provides declarative flatpak package management with automatic updates
# Uses nix-flatpak for declarative configuration

let
  cfg = config.system.flatpak;
in
{
  imports = [
    inputs.nix-flatpak.nixosModules.nix-flatpak
  ];

  options.system.flatpak = {
    enable = lib.mkEnableOption "Flatpak with declarative package management";

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "com.github.tchx84.Flatseal" ];
      description = "List of Flatpak packages to install";
      example = [
        "com.github.tchx84.Flatseal"
        "org.mozilla.firefox"
        "com.spotify.Client"
        "org.pvermeer.WebAppHub"
      ];
    };

    autoUpdate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable automatic weekly Flatpak updates";
    };

    updateOnActivation = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Update Flatpaks on system activation (can be slow)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable Flatpak service
    services.flatpak = {
      enable = true;

      # Configure automatic updates
      update = {
        auto = {
          enable = cfg.autoUpdate;
          onCalendar = "weekly";
        };
        onActivation = cfg.updateOnActivation;
      };

      # Declare packages to install
      inherit (cfg) packages;

      # Flathub remote is added automatically by nix-flatpak
      # Custom remotes can be added here if needed:
      # remotes = [
      #   {
      #     name = "flathub-beta";
      #     location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
      #   }
      # ];
    };

    # Enable XDG portal for better desktop integration
    xdg.portal.xdgOpenUsePortal = true;
  };
}
