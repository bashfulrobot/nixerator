{ pkgs, ... }:

# Intel iGPU (UHD 620, Gen9.5) hardware video acceleration for srv. Host-side
# only -- no GPU passthrough into the darkstar Talos VMs, since the Jellyfin
# pod can schedule onto any worker so pinning the GPU to one VM isn't worth
# it. This just makes the iGPU usable if Jellyfin (or other media tooling)
# ever runs on srv metal directly.
#
# VAAPI via intel-media-driver (iHD) is the correct driver for Gen9.5 --
# Intel MediaSDK/oneVPL QSV is deprecated on this generation, don't chase it
# for host use.
#
# The NVIDIA MX150 dGPU is left on nouveau (kernel default) and already
# runtime-suspends (power/control=auto) -- no NVENC, no console role, not
# worth the proprietary driver.
{
  hardware = {
    enableRedistributableFirmware = true;

    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver # iHD VAAPI driver
        intel-compute-runtime # OpenCL
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    libva-utils # vainfo
    clinfo
    intel-gpu-tools # intel_gpu_top
  ];
}
