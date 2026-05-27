{
  lib,
  config,
  globals,
  ...
}:
let
  cfg = config.server.netbootXyz;

  # Build a Docker `-p [HOSTIP:]HOSTPORT:CONTAINERPORT[/proto]` token.
  # When hostIp is empty, Docker binds to 0.0.0.0 (the default). IPv6
  # literals must be bracketed so Docker doesn't mis-parse the colons.
  bindSpec =
    hostIp: hostPort: containerPort: proto:
    let
      isIpv6 = lib.hasInfix ":" hostIp;
      prefix =
        if hostIp == "" then
          ""
        else if isIpv6 then
          "[${hostIp}]:"
        else
          "${hostIp}:";
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

  # Ports this module wants to block from a given interface pattern via a
  # nat/PREROUTING RETURN, so Docker's published-port DNAT (which has no
  # input-interface predicate) doesn't expose the listeners to traffic
  # arriving on bridges we don't trust.
  bridgeBlockPorts = [
    {
      proto = "tcp";
      port = cfg.adminPort;
    }
  ]
  ++ lib.optional cfg.localMirror.enable {
    proto = "tcp";
    port = cfg.httpPort;
  }
  ++ [
    {
      proto = "udp";
      port = cfg.tftpPort;
    }
  ];

  bridgeBlockLine =
    iface:
    { proto, port }:
    "iptables -t nat -I PREROUTING -i ${iface} -d ${cfg.lanAddress} -p ${proto} --dport ${toString port} -j RETURN";

  bridgeBlockStopLine =
    iface:
    { proto, port }:
    "iptables -t nat -D PREROUTING -i ${iface} -d ${cfg.lanAddress} -p ${proto} --dport ${toString port} -j RETURN 2>/dev/null || true";

  bridgeBlockEnabled = cfg.blockBridges != [ ] && cfg.lanAddress != "";

  bridgeBlockCommands = lib.concatStringsSep "\n" (
    lib.concatMap (iface: map (bridgeBlockLine iface) bridgeBlockPorts) cfg.blockBridges
  );

  bridgeBlockStopCommands = lib.concatStringsSep "\n" (
    lib.concatMap (iface: map (bridgeBlockStopLine iface) bridgeBlockPorts) cfg.blockBridges
  );
in
{
  options.server.netbootXyz = {
    enable = lib.mkEnableOption "netboot.xyz iPXE boot menu server";

    image = lib.mkOption {
      type = lib.types.str;
      # Digest-pinned to ghcr.io/netbootxyz/netbootxyz:latest as of 2026-05-27
      # (tag 0.7.6-nbxyz23). Bump by looking up the new digest, e.g.
      #   docker manifest inspect ghcr.io/netbootxyz/netbootxyz:latest | head
      # and updating both this default and the docs upgrade snippet.
      default = "ghcr.io/netbootxyz/netbootxyz@sha256:39bb40c85d1f6e500b3df1871460f88609215735c224b234b9e6e4e849faf92b";
      description = ''
        OCI image to run. Defaults to a digest-pinned reference of the
        official upstream image. Bump the digest when you want a newer
        build -- a floating `:latest` tag would let a compromised
        upstream silently push code that runs root-equivalent inside
        the container with a bind mount on `/config` and `/assets`.
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
        Host IP to bind the LAN-facing container ports (TFTP and, if
        `localMirror.enable`, the boot-file HTTP port) to. Empty means
        Docker binds 0.0.0.0 and host-firewall scoping is the only
        exposure control -- not safe on hosts that otherwise have a
        permissive INPUT chain (e.g. KVM routing). Set to the IP of
        `lanInterface` for proper isolation.
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

    blockBridges = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "virbr+" ];
      description = ''
        Bridge interface patterns whose source traffic must NOT be able
        to reach the container's published ports via Docker's DNAT.
        Each pattern gets a `nat/PREROUTING -j RETURN` rule that bypasses
        Docker's port DNAT for packets arriving on that bridge, so e.g.
        libvirt guests cannot hit the unauthenticated admin UI even
        though the host's INPUT chain is otherwise permissive. Requires
        `lanAddress` to be set (the rules match on destination IP).
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
        Defaults to 8080 to avoid colliding with Caddy on 80. Only
        published and opened in the firewall when
        `localMirror.enable = true`.
      '';
    };

    adminPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "TCP port for the netboot.xyz web admin UI.";
    };

    localMirror.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Publish the container's nginx (boot-file HTTP) port and open it
        in the firewall. Only useful once you've edited the admin UI's
        `boot.cfg` so `live_endpoint = http://<lanAddress>:<httpPort>`.
        Until then the listener is reachable LAN-wide but does nothing,
        so it's gated off by default to avoid exposing an unused
        attack surface (any future nginx CVE in the container build
        would otherwise be unauthenticated-reachable).
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/netboot.xyz";
      description = ''
        Host directory for persistent container state. `<stateDir>/config`
        holds menus and settings, `<stateDir>/assets` holds locally
        cached ISOs. Created with mode 0750 so non-`puid` host users
        can't read menus or cached assets without `sudo`.
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
      {
        assertion = cfg.blockBridges == [ ] || cfg.lanAddress != "";
        message = ''
          server.netbootXyz.blockBridges requires server.netbootXyz.lanAddress to be
          set -- the PREROUTING RETURN rules need a destination IP to match against.
        '';
      }
    ];

    systemd.tmpfiles.settings."10-netboot-xyz" = {
      "${cfg.stateDir}".d = {
        mode = "0750";
        user = toString cfg.puid;
        group = toString cfg.pgid;
      };
      "${cfg.stateDir}/config".d = {
        mode = "0750";
        user = toString cfg.puid;
        group = toString cfg.pgid;
      };
      "${cfg.stateDir}/assets".d = {
        mode = "0750";
        user = toString cfg.puid;
        group = toString cfg.pgid;
      };
    };

    virtualisation.oci-containers.containers."netboot-xyz" = {
      inherit (cfg) image;
      autoStart = true;
      # TFTPD_OPTS is only set when the toggle is on -- an empty env var
      # could be passed as a literal empty arg to dnsmasq inside the
      # container, which dnsmasq rejects with "bad command line options".
      environment = {
        PUID = toString cfg.puid;
        PGID = toString cfg.pgid;
        TZ = globals.defaults.timeZone;
      }
      // lib.optionalAttrs cfg.tftpSinglePort {
        TFTPD_OPTS = "--tftp-single-port";
      };
      volumes = [
        "${cfg.stateDir}/config:/config"
        "${cfg.stateDir}/assets:/assets"
      ];
      ports = [
        (bindSpec cfg.lanAddress cfg.tftpPort 69 "udp")
      ]
      ++ lib.optional cfg.localMirror.enable (bindSpec cfg.lanAddress cfg.httpPort 80 "")
      ++ adminPortMappings;
    };

    # mkMerge (not `//`) so an interface listed in both lanInterface and
    # adminInterfaces (the default for enp3s0) gets its TCP port lists
    # concatenated rather than overwritten. Listener-binding via
    # lanAddress / adminAddresses is the primary exposure control; this
    # firewall scope is defense-in-depth.
    networking.firewall.interfaces = lib.mkMerge [
      {
        ${cfg.lanInterface} = {
          allowedUDPPorts = [ cfg.tftpPort ];
        }
        // lib.optionalAttrs cfg.localMirror.enable {
          allowedTCPPorts = [ cfg.httpPort ];
        };
      }
      (lib.genAttrs cfg.adminInterfaces (_: {
        allowedTCPPorts = [ cfg.adminPort ];
      }))
    ];

    # Block libvirt-bridge traffic from reaching the container's published
    # ports. Docker's DNAT lives in nat/PREROUTING with no input-interface
    # predicate, so without these rules a guest VM that routes through srv
    # toward `lanAddress` would hit the unauthenticated admin UI before
    # any INPUT/FORWARD ACL runs. RETURN bypasses Docker's chain for that
    # source; the kernel then tries to deliver locally, finds no listener
    # on lanAddress (Docker's listener is on docker0), and the packet is
    # dropped by the firewall.
    networking.firewall.extraCommands = lib.mkIf bridgeBlockEnabled bridgeBlockCommands;
    networking.firewall.extraStopCommands = lib.mkIf bridgeBlockEnabled bridgeBlockStopCommands;
  };
}
