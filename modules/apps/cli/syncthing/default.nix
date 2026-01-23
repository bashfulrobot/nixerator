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
          inherit (secrets.syncthing.gui) user password;
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

            ".ssh" = {
              path = "${globals.user.homeDirectory}/.ssh";
              devices = [ "qbert" ];
              ignorePerms = false;
              versioning = staggeredVersioning;
            };

            ".kube" = {
              path = "${globals.user.homeDirectory}/.kube";
              devices = [ "qbert" ];
              versioning = staggeredVersioning;
            };

            ".talos" = {
              path = "${globals.user.homeDirectory}/.talos";
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

            ".ssh" = {
              path = "${globals.user.homeDirectory}/.ssh";
              devices = [ "donkey-kong" ];
              ignorePerms = false;
              versioning = staggeredVersioning;
            };

            ".kube" = {
              path = "${globals.user.homeDirectory}/.kube";
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };

            ".talos" = {
              path = "${globals.user.homeDirectory}/.talos";
              devices = [ "donkey-kong" ];
              versioning = staggeredVersioning;
            };

          };
        };
      })
    ];

    # Home Manager configuration for desktop file and stignore files
    home-manager.users.${globals.user.name} = {
      home.file = {
        # Override package desktop file since we use custom configDir
        "syncthing-ui.desktop" = {
          text = ''
            [Desktop Entry]
            Name=Syncthing Web UI
            Exec=xdg-open http://localhost:8384
            Icon=syncthing
            Type=Application
            Categories=Network;FileTransfer;
          '';
          target = ".local/share/applications/syncthing-ui.desktop";
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
