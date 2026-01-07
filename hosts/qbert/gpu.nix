{ pkgs, ... }:

# AMD GPU Configuration for qbert
# Based on previous qbert configuration from nixcfg-main

{
  # Load AMDGPU driver in initramfs
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Hardware configuration for AMD GPU
  hardware = {
    # Enable graphics hardware acceleration
    graphics = {
      enable = true;
      enable32Bit = true;  # Required for 32-bit applications and games
    };

    # Load AMDGPU driver early for proper resolution during boot
    amdgpu.initrd.enable = true;

    # Ensure firmware is available for GPU
    firmware = [ pkgs.linux-firmware ];
  };

  # Fix for monitor not waking after sleep/suspend
  # Disable runtime PM (BACO) which causes SMU suspend/resume failures
  # Error: "suspend of IP block <smu> failed -22"
  boot.kernelParams = [
    "amdgpu.runpm=0"  # Disable runtime power management (BACO)
  ];

  # OpenCL support for compute tasks (uncomment if needed)
  # hardware.amdgpu.opencl.enable = true;

  # LACT - Linux AMDGPU Controller Tool (uncomment if needed)
  # Provides GUI for overclocking, undervolting, fan curves
  # services.lact.enable = true;
}
