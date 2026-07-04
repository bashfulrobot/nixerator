{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.server.nfs;

  squashValues = [
    "root_squash"
    "all_squash"
    "no_root_squash"
  ];

  # Build the options string for one export entry.
  mkExportOptions =
    e:
    let
      rwFlag = if e.readOnly then "ro" else "rw";
      syncFlag = if e.sync then "sync" else "async";
      subtreeFlag = if e.subtreeCheck then "subtree_check" else "no_subtree_check";
      anonFlags = lib.optionalString (e.squash == "all_squash" || e.squash == "root_squash") (
        (lib.optionalString (e.anonUid != null) ",anonuid=${toString e.anonUid}")
        + (lib.optionalString (e.anonGid != null) ",anongid=${toString e.anonGid}")
      );
    in
    "${rwFlag},${syncFlag},${subtreeFlag},${e.squash}${anonFlags}";

  # Build one exports(5) line for an export.
  mkExportLine =
    exportCfg:
    assert lib.assertMsg (exportCfg.clients != [ ])
      "server.nfs: export ${exportCfg.path} has an empty clients list; an empty list produces an inaccessible export that no client can mount";
    let
      opts = mkExportOptions exportCfg;
      clientEntries = lib.concatMapStringsSep " " (cidr: "${cidr}(${opts})") exportCfg.clients;
    in
    "${exportCfg.path} ${clientEntries}";

in
{
  options = {
    server.nfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable NFS server with configurable exports.";
      };

      exports = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              path = lib.mkOption {
                type = lib.types.str;
                description = "Server-side export path.";
              };

              bindMount = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Bind-mount this source path onto `path` before exporting.";
              };

              clients = lib.mkOption {
                type = lib.types.listOf (
                  lib.types.addCheck lib.types.str (s: builtins.match ".*[[:space:]].*" s == null)
                );
                default = [ ];
                example = [ "192.168.168.0/23" ];
                description = ''
                  CIDR blocks allowed to mount this export. Must be non-empty;
                  an empty list produces an inaccessible export that no client
                  can mount (caught at eval time). Values must not contain
                  whitespace or newlines; the check is enforced at eval time to
                  prevent exports(5) injection via multi-line strings.
                '';
              };

              readOnly = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Export read-only (ro). False gives read-write (rw).";
              };

              sync = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Require writes to be committed to disk before replying (sync). Safer; async is faster but risks data loss on crash.";
              };

              subtreeCheck = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable subtree checking. Disabled by default; improves reliability for most workloads.";
              };

              squash = lib.mkOption {
                type = lib.types.enum squashValues;
                default = "root_squash";
                description = ''
                  UID/GID squash mode.
                  - root_squash: map root (UID 0) to anonuid/anongid; other UIDs pass through. Default; safe for k8s workloads where pods run as non-root.
                  - all_squash: map every client UID/GID to anonuid/anongid. Simple but breaks pods that expect to own their files with a specific UID.
                  - no_root_squash: pass root through unmapped. Privilege escalation
                    risk: root on any client in the `clients` CIDR list can write files
                    as root on the NFS server, including setuid binaries. Only use with
                    a tightly scoped `/32` client list and a clear operational reason.
                '';
              };

              anonUid = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "UID to map squashed clients to. Only used when squash = all_squash or root_squash remaps root.";
              };

              anonGid = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "GID to map squashed clients to.";
              };

              uid = lib.mkOption {
                type = lib.types.int;
                default = 1000;
                description = "UID for server-side directory ownership (tmpfiles).";
              };

              gid = lib.mkOption {
                type = lib.types.int;
                default = 100;
                description = "GID for server-side directory ownership (tmpfiles).";
              };
            };
          }
        );
        default = { };
        description = "NFS exports.";
      };

      additionalPaths = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
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
          }
        );
        default = [ ];
        description = "Additional paths to create with tmpfiles.";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      nfs-utils
    ];

    fileSystems = lib.mapAttrs' (
      _: exportCfg:
      lib.nameValuePair exportCfg.path (
        lib.mkIf (exportCfg.bindMount != null) {
          device = exportCfg.bindMount;
          fsType = "none";
          options = [ "bind" ];
        }
      )
    ) cfg.exports;

    services.nfs.server = {
      enable = true;
      exports = lib.concatStringsSep "\n" (lib.mapAttrsToList (_: mkExportLine) cfg.exports);
    };

    systemd.tmpfiles.rules =
      (lib.mapAttrsToList (_: exportCfg: "d ${exportCfg.path} 0755 nobody nogroup -") cfg.exports)
      ++ (lib.mapAttrsToList (
        _: exportCfg:
        lib.optionalString (
          exportCfg.bindMount != null
        ) "d ${exportCfg.bindMount} 0755 ${toString exportCfg.uid} ${toString exportCfg.gid} -"
      ) cfg.exports)
      ++ (map (
        pathCfg: "d ${pathCfg.path} ${pathCfg.mode} ${toString pathCfg.uid} ${toString pathCfg.gid} -"
      ) cfg.additionalPaths);
  };
}
