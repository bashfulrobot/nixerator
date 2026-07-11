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
      type = lib.types.listOf (
        lib.types.addCheck lib.types.str (s: builtins.match ".*[[:space:]].*" s == null)
      );
      default = [ ];
      example = [ "192.168.168.0/23" ];
      description = ''
        CIDR blocks allowed to connect over TCP/IP using scram-sha-256.
        Localhost connections are always trusted regardless of this list.
        Values must not contain whitespace or newlines; the check is enforced
        at eval time to prevent config-injection via multi-line strings.
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
      settings = cfg.settings // lib.optionalAttrs (cfg.port != 5432) { inherit (cfg) port; };
      dataDir = lib.mkIf (cfg.dataDir != null) cfg.dataDir;
      enableTCPIP = cfg.allowedCIDRs != [ ];

      # Local connections (Unix socket and loopback TCP) use trust so the
      # postgres admin can connect without a password for maintenance and so
      # NixOS ensureUsers/ensureDatabases can run at service start. This is
      # intentional for a single-user homelab: the trust boundary is the OS
      # user boundary, not PostgreSQL. If srv ever hosts multi-tenant
      # workloads, harden to `peer` on the socket and `scram-sha-256` on
      # loopback, then set passwords for all application roles.
      # mkOverride 900: beats the NixOS upstream default (1000) but yields to
      # user config (100) and lib.mkForce (50), so other modules can still
      # extend pg_hba.conf without being silently discarded.
      authentication = lib.mkOverride 900 (
        ''
          local all all               trust
          host  all all 127.0.0.1/32  trust
          host  all all ::1/128       trust
        ''
        + lib.concatMapStrings (cidr: "host  all all ${cidr}  scram-sha-256\n") cfg.allowedCIDRs
      );
    };

    # Open the PostgreSQL port only to the configured CIDRs. Uses
    # extraInputRules (nftables) rather than allowedTCPPorts so that the
    # firewall enforces the same CIDR list as pg_hba.conf instead of opening
    # the port globally. Requires nftables to be active (forced on by
    # server.kvm, the fleet's virtualisation module, when enabled on the
    # host). Non-allowedCIDRs sources get an explicit reject so they see
    # "connection refused" rather than a silent timeout.
    networking.firewall.extraInputRules = lib.mkIf (cfg.allowedCIDRs != [ ]) (
      lib.concatMapStrings (
        cidr:
        let
          isIPv6 = lib.hasInfix ":" cidr;
          family = if isIPv6 then "ip6" else "ip";
        in
        "${family} saddr ${cidr} tcp dport ${toString cfg.port} accept\n"
      ) cfg.allowedCIDRs
      + "tcp dport ${toString cfg.port} reject\n"
    );
  };
}
