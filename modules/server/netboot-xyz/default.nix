{
  lib,
  config,
  globals,
  ...
}:
let
  cfg = config.server.netbootXyz;
in
{
  options.server.netbootXyz = {
    enable = lib.mkEnableOption "netboot.xyz iPXE boot menu server (LinuxServer container)";

    image = lib.mkOption {
      type = lib.types.str;
      default = "lscr.io/linuxserver/netbootxyz:latest";
      description = ''
        OCI image to run. Pin to a tag (e.g. `:0.7.5`) for reproducible
        deployments; `:latest` is fine for a personal lab where menu
        churn is desirable.
      '';
    };

    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "enp3s0";
      description = ''
        LAN interface on which PXE clients live. TFTP and the boot-file
        HTTP port are opened on this interface only.
      '';
    };

    adminInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "enp3s0"
        "tailscale0"
      ];
      description = ''
        Interfaces on which the web admin UI port is reachable. The UI
        has no authentication, so restrict to trusted interfaces only.
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
        Defaults to 8080 to avoid colliding with Caddy on 80. iPXE
        chainload URLs must include this port.
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
      description = "PUID env var passed to the LinuxServer container (file ownership inside bind mounts).";
    };

    pgid = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "PGID env var passed to the LinuxServer container.";
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

    virtualisation.oci-containers.backend = lib.mkDefault "docker";

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
      };
      volumes = [
        "${cfg.stateDir}/config:/config"
        "${cfg.stateDir}/assets:/assets"
      ];
      ports = [
        "${toString cfg.adminPort}:3000"
        "${toString cfg.tftpPort}:69/udp"
        "${toString cfg.httpPort}:80"
      ];
    };

    # mkMerge (not `//`) so an interface listed in both lanInterface and
    # adminInterfaces (the default for enp3s0) gets its TCP port lists
    # concatenated rather than overwritten.
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
