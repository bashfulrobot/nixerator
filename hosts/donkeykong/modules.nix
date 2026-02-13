_:

{
  # Apps
  apps.cli.syncthing = {
    enable = true;
    host.donkeykong = true;
  };

  apps.cli.ollama.acceleration = "vulkan";

  # Server modules
  server = {
    kvm = {
      enable = true;
      routing = {
        enable = true;
        externalInterface = "wlp0s0f3";
        internalInterfaces = [
          "virbr1"
          "virbr2"
          "virbr3"
          "virbr4"
          "virbr5"
          "virbr6"
          "virbr7"
        ];
        proxyArpInterfaces = [ "wlp0s0f3" ];
      };
    };
  };
}
