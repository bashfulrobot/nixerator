{ config, pkgs, ... }:

# AMD GPU Configuration for qbert
# Based on previous qbert configuration from nixcfg-main

{
  # Load AMDGPU driver in initramfs
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Enable graphics hardware acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # Required for 32-bit applications and games
  };

  # Load AMDGPU driver early for proper resolution during boot
  hardware.amdgpu.initrd.enable = true;

  # Ensure firmware is available for GPU
  hardware.firmware = [ pkgs.linux-firmware ];

  # Troubleshooting options (uncomment if experiencing desktop lockups):
  # boot.kernelParams = [
  #   "amdgpu.dc=0"      # Disable Display Core
  #   "amdgpu.gfxoff=0"  # Disable power gating
  # ];

  # OpenCL support for compute tasks (uncomment if needed)
  # hardware.amdgpu.opencl.enable = true;

  # LACT - Linux AMDGPU Controller Tool (uncomment if needed)
  # Provides GUI for overclocking, undervolting, fan curves
  # services.lact.enable = true;
}
