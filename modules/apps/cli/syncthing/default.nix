{ globals, lib, pkgs, config, secrets, ... }:

let
  cfg = config.apps.cli.syncthing;

  # Versioning configurations
  simpleVersioning = {
    type = "simple";
    params = {
      keep = "10";
    };
  };

  staggeredVersioning = {
    type = "staggered";
    params = {
      cleanInterval = "3600";    # 1 hour in seconds
      maxAge = "7776000";         # 90 days in seconds
    };
  };

in
{
  options = {
    apps.cli.syncthing = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Syncthing file synchronization.";
      };

      host = {
        donkeykong = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Syncthing configuration for donkeykong host.";
        };

        qbert = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Syncthing configuration for qbert host.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gnomeExtensions.syncthing-indicator
      syncthing
    ];

    services.syncthing = lib.mkMerge [
      # Base configuration shared across all hosts
      {
        enable = true;
        systemService = true;
        user = globals.user.name;
        group = "users";
        dataDir = globals.user.homeDirectory;
        guiAddress = "0.0.0.0:8384";
        openDefaultPorts = true;
        overrideDevices = true;
        overrideFolders = true;

        settings.gui = {
          user = secrets.syncthing.gui.user;
          password = secrets.syncthing.gui.password;
        };
      }

      # donkeykong host configuration
      (lib.mkIf cfg.host.donkeykong {
        configDir = "${globals.user.homeDirectory}/.config/syncthing/donkeykong";

        settings = {
          devices = {
            "qbert" = {
              addresses = [ "tcp://${secrets.qbert.tailscale_ip}:22000" ];
              id = secrets.qbert.syncthing_id;
            };
          };

          folders = {
            "Desktop" = {
              path = "${globals.user.homeDirectory}/Desktop";
              devices = [ "qbert" ];
              versioning = simpleVersioning;
            };

            "Documents" = {
              path = "${globals.user.homeDirectory}/Documents";
              devices = [ "qbert" ];
              versioning = staggeredVersioning;
            };

            "Downloads" = {
              path = "${globals.user.homeDirectory}/Downloads";
              devices = [ "qbert" ];
              versioning = simpleVersioning;
            };

            "Music" = {
              path = "${globals.user.homeDirectory}/Music";
              devices = [ "qbert" ];
              versioning = simpleVersioning;
            };

            "Pictures" = {
              path = "${globals.user.homeDirectory}/Pictures";
              devices = [ "qbert" ];
              versioning = simpleVersioning;
            };

            "Videos" = {
              path = "${globals.user.homeDirectory}/Videos";
              devices = [ "qbert" ];
              versioning = simpleVersioning;
            };

            "dev" = {
              path = "${globals.user.homeDirectory}/dev";
              devices = [ "qbert" ];
              versioning = staggeredVersioning;
            };

            ".gnupg" = {
              path = "${globals.user.homeDirectory}/.gnupg";
              devices = [ "qbert" ];
              ignorePerms = false;
              versioning = staggeredVersioning;
            };

            ".aws" = {
              path = "${globals.user.homeDirectory}/.aws";
              devices = [ "qbert" ];
              versioning = staggeredVersioning;
            };

            ".kube" = {
              path = "${globals.user.homeDirectory}/.kube";
              devices = [ "qbert" ];
              versioning = staggeredVersioning;
            };

            ".doppler" = {
              path = "${globals.user.homeDirectory}/.doppler";
              devices = [ "qbert" ];
              versioning = staggeredVersioning;
            };

            "virter" = {
              path = "${globals.user.homeDirectory}/.config/virter";
              devices = [ "qbert" ];
              versioning = staggeredVersioning;
            };

            "bin" = {
              path = "${globals.user.homeDirectory}/bin";
              devices = [ "qbert" ];
              versioning = staggeredVersioning;
            };
          };
        };
      })

      # qbert host configuration
      (lib.mkIf cfg.host.qbert {
        configDir = "${globals.user.homeDirectory}/.config/syncthing/qbert";

        settings = {
          devices = {
            "donkey-kong" = {
              addresses = [ "tcp://${secrets.donkey-kong.tailscale_ip}:22000" ];
              id = secrets.donkey-kong.syncthing_id;
            };
          };

          folders = {
            "Desktop" = {
              path = "${globals.user.homeDirectory}/Desktop";
              devices = [ "donkey-kong" ];
              versioning = simpleVersioning;
            };

            "Documents" = {
              path = "${globals.user.homeDirectory}/Documents";
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };

            "Downloads" = {
              path = "${globals.user.homeDirectory}/Downloads";
              devices = [ "donkey-kong" ];
              versioning = simpleVersioning;
            };

            "Music" = {
              path = "${globals.user.homeDirectory}/Music";
              devices = [ "donkey-kong" ];
              versioning = simpleVersioning;
            };

            "Pictures" = {
              path = "${globals.user.homeDirectory}/Pictures";
              devices = [ "donkey-kong" ];
              versioning = simpleVersioning;
            };

            "Videos" = {
              path = "${globals.user.homeDirectory}/Videos";
              devices = [ "donkey-kong" ];
              versioning = simpleVersioning;
            };

            "dev" = {
              path = "${globals.user.homeDirectory}/dev";
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };

            ".gnupg" = {
              path = "${globals.user.homeDirectory}/.gnupg";
              devices = [ "donkey-kong" ];
              ignorePerms = false;
              versioning = staggeredVersioning;
            };

            ".aws" = {
              path = "${globals.user.homeDirectory}/.aws";
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };

            ".kube" = {
              path = "${globals.user.homeDirectory}/.kube";
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };

            ".doppler" = {
              path = "${globals.user.homeDirectory}/.doppler";
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };

            "virter" = {
              path = "${globals.user.homeDirectory}/.config/virter";
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };

            "bin" = {
              path = "${globals.user.homeDirectory}/bin";
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };
          };
        };
      })
    ];

    # Home Manager configuration for desktop files and icons
    home-manager.users.${globals.user.name} = {
      home.file = {
        "syncthing.desktop" = {
          text = ''
            [Desktop Entry]
            Type=Application
            Name=Syncthing
            StartupWMClass=chrome-localhost__-Default
            Comment=Launch Syncthing Web UI
            Icon=${globals.user.homeDirectory}/.local/share/xdg-desktop-portal/icons/192x192/syncthing.png
            Exec=google-chrome --ozone-platform-hint=auto --force-dark-mode --enable-features=WebUIDarkMode --app="http://localhost:8384" %U

            Terminal=false
          '';
          target = ".local/share/applications/syncthing.desktop";
        };

        "syncthing.png" = {
          source = ./syncthing.png;
          target = ".local/share/xdg-desktop-portal/icons/192x192/syncthing.png";
        };

        "dev/.stignore" = {
          text = ''
            .git
          '';
          target = "dev/.stignore";
        };
      };
    };
  };
}
