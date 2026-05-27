{
  lib,
  config,
  globals,
  ...
}:
let
  cfg = config.server.netbootXyz;

  # Build a Docker `-p [HOSTIP:]HOSTPORT:CONTAINERPORT[/proto]` token.
  # When hostIp is empty, Docker binds to 0.0.0.0 (the default).
  bindSpec =
    hostIp: hostPort: containerPort: proto:
    let
      prefix = if hostIp == "" then "" else "${hostIp}:";
      suffix = if proto == "" then "" else "/${proto}";
    in
    "${prefix}${toString hostPort}:${toString containerPort}${suffix}";

  # Admin port may be bound to multiple host IPs (LAN + Tailscale). When
  # adminAddresses is empty fall back to 0.0.0.0 and rely on firewall scoping.
  adminPortMappings =
    if cfg.adminAddresses == [ ] then
      [ (bindSpec "" cfg.adminPort 3000 "") ]
    else
      map (ip: bindSpec ip cfg.adminPort 3000 "") cfg.adminAddresses;
in
{
  options.server.netbootXyz = {
    enable = lib.mkEnableOption "netboot.xyz iPXE boot menu server";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/netbootxyz/netbootxyz:latest";
      description = ''
        OCI image to run. Defaults to the official upstream image. Pin to a
        tag (e.g. `:0.7.5`) for reproducible deployments; `:latest` is fine
        for a personal lab where menu churn is desirable.
      '';
    };

    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "enp3s0";
      description = ''
        LAN interface PXE clients live on. TFTP and the boot-file HTTP
        port are opened on this interface in the host firewall. Pairs
        with `lanAddress` for defense-in-depth -- listener-binding is
        the primary control, the firewall is the backstop.
      '';
    };

    adminInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "enp3s0"
        "tailscale0"
      ];
      description = ''
        Interfaces on which the web admin UI port is reachable in the host
        firewall. The UI has no authentication so restrict to trusted
        interfaces. Pairs with `adminAddresses` for defense-in-depth.
      '';
    };

    lanAddress = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "192.168.168.1";
      description = ''
        Host IP to bind the LAN-facing container ports (TFTP and boot-file
        HTTP) to. Empty means Docker binds 0.0.0.0 and host-firewall
        scoping is the only exposure control -- not safe on hosts that
        otherwise have a permissive INPUT chain (e.g. KVM routing). Set
        to the IP of `lanInterface` for proper isolation.
      '';
    };

    adminAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "192.168.168.1"
        "100.64.187.14"
      ];
      description = ''
        Host IPs to bind the admin UI port to. Empty means Docker binds
        0.0.0.0 (firewall-only control). Set to the IPs of the admin-
        accessible interfaces for proper isolation.
      '';
    };

    tftpPort = lib.mkOption {
      type = lib.types.port;
      default = 69;
      description = "UDP TFTP port for PXE bootstrap.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = ''
        TCP port the container's boot-file HTTP server is published on.
        Defaults to 8080 to avoid colliding with Caddy on 80. Only useful
        if you configure local-mirror menus -- see
        `extras/docs/netboot.md` for how to point `boot.cfg` at this
        endpoint.
      '';
    };

    adminPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "TCP port for the netboot.xyz web admin UI.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/netboot.xyz";
      description = ''
        Host directory for persistent container state. `<stateDir>/config`
        holds menus and settings, `<stateDir>/assets` holds locally
        cached ISOs.
      '';
    };

    puid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = ''
        PUID env var passed to the container (file ownership inside bind
        mounts). Defaults to 1000 to match a typical first NixOS normal
        user. Adjust if your shell user has a different UID.
      '';
    };

    pgid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = ''
        PGID env var passed to the container. Defaults to 1000 (matches
        upstream image default). If you need SSH-side edits to
        `<stateDir>/config/menus`, either align this to your shell
        user's primary group, or `chmod g+w` after first run.
      '';
    };

    tftpSinglePort = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Pass `--tftp-single-port` to dnsmasq inside the container so all
        TFTP traffic uses port 69 instead of negotiating an ephemeral
        data port. Required when the container is reached via Docker NAT
        (the default) because conntrack does not auto-attach the TFTP
        helper on modern kernels. Disable only if you have configured a
        TFTP conntrack helper out-of-band.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.docker.enable;
        message = ''
          server.netbootXyz.enable = true requires virtualisation.docker.enable = true.
          Enable apps.cli.docker on this host (or set the Docker option directly).
        '';
      }
    ];

    systemd.tmpfiles.settings."10-netboot-xyz" = {
      "${cfg.stateDir}".d = {
        mode = "0755";
        user = toString cfg.puid;
        group = toString cfg.pgid;
      };
      "${cfg.stateDir}/config".d = {
        mode = "0755";
        user = toString cfg.puid;
        group = toString cfg.pgid;
      };
      "${cfg.stateDir}/assets".d = {
        mode = "0755";
        user = toString cfg.puid;
        group = toString cfg.pgid;
      };
    };

    virtualisation.oci-containers.containers."netboot-xyz" = {
      inherit (cfg) image;
      autoStart = true;
      environment = {
        PUID = toString cfg.puid;
        PGID = toString cfg.pgid;
        TZ = globals.defaults.timeZone;
        TFTPD_OPTS = lib.optionalString cfg.tftpSinglePort "--tftp-single-port";
      };
      volumes = [
        "${cfg.stateDir}/config:/config"
        "${cfg.stateDir}/assets:/assets"
      ];
      ports = [
        (bindSpec cfg.lanAddress cfg.tftpPort 69 "udp")
        (bindSpec cfg.lanAddress cfg.httpPort 80 "")
      ]
      ++ adminPortMappings;
    };

    # mkMerge (not `//`) so an interface listed in both lanInterface and
    # adminInterfaces (the default for enp3s0) gets its TCP port lists
    # concatenated rather than overwritten. Note: on a host whose INPUT
    # chain is already permissively open (e.g. KVM routing), per-interface
    # firewall scoping is decorative -- the listener-binding controlled by
    # lanAddress / adminAddresses is the primary exposure control.
    networking.firewall.interfaces = lib.mkMerge [
      {
        ${cfg.lanInterface} = {
          allowedUDPPorts = [ cfg.tftpPort ];
          allowedTCPPorts = [ cfg.httpPort ];
        };
      }
      (lib.genAttrs cfg.adminInterfaces (_: {
        allowedTCPPorts = [ cfg.adminPort ];
      }))
    ];
  };
}
