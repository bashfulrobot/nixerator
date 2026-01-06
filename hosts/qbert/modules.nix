{ config, pkgs, lib, globals, ... }:

{
  # Apps
  apps.cli.syncthing = {
    enable = true;
    host.qbert = true;
  };

  # Server modules
  server = {
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
