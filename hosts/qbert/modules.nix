{ secrets, ... }:

{
  # Apps
  apps.cli.plakar = {
    stores.b2-backup = {
      type = "s3";
      location = secrets.plakar.qbert.repository;
      accessKey = secrets.plakar.qbert.b2_account_id;
      secretAccessKey = secrets.plakar.qbert.b2_account_key;
      passphrase = secrets.plakar.qbert.passphrase;
    };

    jobs.home-to-b2 = {
      store = "@b2-backup";
      paths = [
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
      interval = "24h";
    };
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
