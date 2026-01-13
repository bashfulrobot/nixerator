{ globals, pkgs, config, lib, ... }:
let
  cfg = config.server.nfs;
  username = globals.user.name;

in {

  options = {
    server.nfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable NFS server with configurable exports.";
      };

      exports = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Path to export via NFS.";
            };

            bindMount = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional bind mount source path.";
            };

            exportConfig = lib.mkOption {
              type = lib.types.str;
              description = "NFS export configuration string (networks and options).";
            };

            uid = lib.mkOption {
              type = lib.types.int;
              default = 1000;
              description = "UID for directory ownership.";
            };

            gid = lib.mkOption {
              type = lib.types.int;
              default = 100;
              description = "GID for directory ownership.";
            };
          };
        });
        default = {};
        description = "NFS exports configuration.";
      };

      additionalPaths = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Additional path to create.";
            };

            mode = lib.mkOption {
              type = lib.types.str;
              default = "0755";
              description = "Directory permissions.";
            };

            uid = lib.mkOption {
              type = lib.types.int;
              default = 1000;
              description = "Directory owner UID.";
            };

            gid = lib.mkOption {
              type = lib.types.int;
              default = 100;
              description = "Directory owner GID.";
            };
          };
        });
        default = [];
        description = "Additional paths to create with tmpfiles.";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      nfs-utils
    ];

    # Create bind mounts for exports
    fileSystems = lib.mapAttrs' (name: exportCfg:
      lib.nameValuePair exportCfg.path (
        lib.mkIf (exportCfg.bindMount != null) {
          device = exportCfg.bindMount;
          options = [ "bind" ];
        }
      )
    ) cfg.exports;

    services.nfs.server = {
      enable = true;
      exports = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: exportCfg:
          "${exportCfg.path} ${exportCfg.exportConfig}"
        ) cfg.exports
      );
    };

    # Create export directories and bind mount sources
    systemd.tmpfiles.rules =
      # Export paths
      (lib.mapAttrsToList (name: exportCfg:
        "d ${exportCfg.path} 0755 nobody nogroup -"
      ) cfg.exports)
      ++
      # Bind mount source paths
      (lib.mapAttrsToList (name: exportCfg:
        lib.optionalString (exportCfg.bindMount != null)
          "d ${exportCfg.bindMount} 0755 ${toString exportCfg.uid} ${toString exportCfg.gid} -"
      ) cfg.exports)
      ++
      # Additional paths
      (map (pathCfg:
        "d ${pathCfg.path} ${pathCfg.mode} ${toString pathCfg.uid} ${toString pathCfg.gid} -"
      ) cfg.additionalPaths);
  };
}
