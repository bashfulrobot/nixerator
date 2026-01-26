{ pkgs, ... }:

# Boot configuration for donkeykong with LUKS encryption

{
  # Boot configuration
  boot = {
    # Use systemd-boot UEFI bootloader
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # LUKS encryption support
    initrd = {
      # Enable LUKS support in initrd
      luks.devices."cryptroot" = {
        # The device will be set up by disko
        # This just enables kernel support and prompts for password
        preLVM = true;
        allowDiscards = true;  # Important for SSD TRIM support
      };

      # NixOS will auto-detect required kernel modules for LUKS/LVM
      # availableKernelModules from hardware-configuration.nix will be used
    };

    # Enable hibernation support (with 32GB swap)
    resumeDevice = "/dev/vg0/swap";
    kernelParams = [
      "resume=/dev/vg0/swap"
      "quiet"
      "splash"
    ];

    # Zen kernel for better desktop performance
    kernelPackages = pkgs.linuxPackages_zen;

    # Disable nova-core (experimental NVIDIA Rust driver) - not needed for Intel GPU
    # and causes build failures due to missing kernel::firmware Rust bindings
    kernelPatches = [{
      name = "disable-nova-core";
      patch = null;
      structuredExtraConfig = {
        DRM_NOVA = pkgs.lib.kernel.no;
      };
    }];
  };
}
