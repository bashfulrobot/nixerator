{ lib, pkgs, secrets, ... }:

{
  # Import only modules that srv used in nixcfg
  imports = [
    ../../modules/apps/cli/docker
    ../../modules/apps/cli/fish
    ../../modules/apps/cli/helix
    ../../modules/apps/cli/starship
    ../../modules/apps/cli/tailscale
    ../../modules/server/kvm
    ../../modules/server/nfs
    ../../modules/server/restic
    ../../modules/system/ssh
  ];

  # CLI applications (matching nixcfg srv)
  apps.cli = {
    docker.enable = true;
    fish.enable = true;
    helix.enable = true;
    starship.enable = true;
    tailscale.enable = true;
  };

  # System modules
  system.ssh.enable = true;

  # Server-specific modules
  server.kvm = {
    enable = true;
    routing = {
      enable = true;
      externalInterface = "enp3s0";
      internalInterfaces = [
        "virbr1"
        "virbr2"
        "virbr3"
        "virbr4"
        "virbr5"
        "virbr6"
        "virbr7"
      ];
      proxyArpInterfaces = [ "ens2" ];
    };
  };

  server.nfs = {
    enable = true;
    exports = {
      spitfire = {
        path = "/exports/spitfire";
        bindMount = "/srv/nfs/spitfire";
        exportConfig = "172.16.166.0/24(rw,sync,no_subtree_check,no_root_squash,all_squash,anonuid=1000,anongid=100)";
        uid = 1000;
        gid = 100;
      };
    };
    additionalPaths = [
      {
        path = "/srv/nfs/restores";
        mode = "0755";
        uid = 1000;
        gid = 100;
      }
    ];
  };

  server.restic = {
    enable = true;
    repository = secrets.restic.srv.restic_repository;
    password = secrets.restic.srv.restic_password;
    awsAccessKeyId = secrets.restic.srv.b2_account_id;
    awsSecretAccessKey = secrets.restic.srv.b2_account_key;
    awsRegion = secrets.restic.srv.region;
    backupPaths = [ "/srv/nfs" ];
    restorePath = "/srv/nfs/restores";
    schedule = "*-*-* 03:00:00";
    keepDaily = 7;
    keepWeekly = 4;
    keepMonthly = 12;
    keepYearly = 2;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}
