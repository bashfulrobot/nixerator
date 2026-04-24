{ secrets, ... }:

{
  # Apps
  apps.cli.restic.backup = {
    enable = true;
    repository = secrets.restic.workstation.restic_repository;
    password = secrets.restic.workstation.restic_password;
    awsAccessKeyId = secrets.restic.workstation.b2_account_id;
    awsSecretAccessKey = secrets.restic.workstation.b2_account_key;
    awsRegion = secrets.restic.workstation.region;
    backupPaths = [
      "/home/dustin/Desktop"
      "/home/dustin/dev"
      "/home/dustin/Documents"
      "/home/dustin/Downloads"
      "/home/dustin/git"
      "/home/dustin/Music"
      "/home/dustin/Pictures"
      "/home/dustin/Videos"
      "/home/dustin/.kube"
      "/home/dustin/.talos"
      "/home/dustin/.config/upsight"
      "/home/dustin/.local/share/upsight"
    ];
    restorePath = "/tmp/restic-restore";
    schedule = "*-*-* 03:00:00";
    keepDaily = 7;
    keepWeekly = 4;
    keepMonthly = 12;
    keepYearly = 2;
  };

  apps.cli.clay = {
    service.enable = true;
    projects = [
      "/home/dustin/git/nixerator"
      "/home/dustin/git/hyprflake"
      "/home/dustin/git/upsight"
      "/home/dustin/git/blackhole"
    ];
  };
  apps.cli.paseo.service.enable = true;
  apps.cli.text-polish.enable = true;
  apps.cli.text-uppercase.enable = true;

  apps.cli.syncthing = {
    enable = true;
    host.qbert = true;
  };

  # apps.cli.ollama.acceleration = "rocm";

  # Server modules
  server = {
    whisper-server = {
      enable = true;
      vulkan = true;
    };
    kvm = {
      enable = true;
      routing = {
        enable = true;
        externalInterface = "enp34s0";
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
  };
}
