_:

{
  # Apps
  apps.cli.clay.service.enable = true;

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
