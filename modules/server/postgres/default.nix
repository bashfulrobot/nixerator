{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.server.postgres;
in
{
  options.server.postgres = {
    enable = lib.mkEnableOption "PostgreSQL server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.postgresql_17;
      description = "PostgreSQL package (controls the major version).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5432;
      description = "Port PostgreSQL listens on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Override the data directory. Null uses the NixOS default
        (/var/lib/postgresql/<version>).
      '';
    };

    allowedCIDRs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "172.16.166.0/24" ];
      description = ''
        CIDR blocks allowed to connect over TCP/IP using scram-sha-256.
        Localhost connections are always trusted regardless of this list.
      '';
    };

    ensureDatabases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Databases to create on first start if they do not already exist.";
    };

    ensureUsers = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "PostgreSQL role name.";
            };
            ensureDBOwnership = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Grant this user ownership of the database with the same name.";
            };
          };
        }
      );
      default = [ ];
      description = ''
        Roles to create on first start if they do not already exist.

        NixOS creates these roles with no password (CREATE ROLE ... WITH LOGIN).
        Because this module enforces scram-sha-256 for all allowedCIDRs, a role
        created here cannot authenticate from the cluster until a password is set
        out-of-band: ALTER ROLE <name> PASSWORD '''...''';
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra postgresql.conf key/value pairs merged into the service config.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      inherit (cfg)
        package
        ensureDatabases
        ensureUsers
        ;
      # port was renamed to settings.port in NixOS 25.11+
      settings = cfg.settings // lib.optionalAttrs (cfg.port != 5432) { port = cfg.port; };
      dataDir = lib.mkIf (cfg.dataDir != null) cfg.dataDir;
      enableTCPIP = cfg.allowedCIDRs != [ ];

      # localhost is always trusted; each entry in allowedCIDRs gets a
      # scram-sha-256 host line so remote k8s workloads authenticate with a
      # password rather than trust.
      authentication = lib.mkOverride 10 (
        ''
          local all all               trust
          host  all all 127.0.0.1/32  trust
          host  all all ::1/128       trust
        ''
        + lib.concatMapStrings (cidr: "host  all all ${cidr}  scram-sha-256\n") cfg.allowedCIDRs
      );
    };

    # Open the PostgreSQL port for remote connections. Source-IP enforcement
    # is handled by pg_hba.conf above; the firewall rule is intentionally
    # broad so we do not need per-host rules when the cluster grows.
    networking.firewall.allowedTCPPorts = lib.mkIf (cfg.allowedCIDRs != [ ]) [ cfg.port ];
  };
}
