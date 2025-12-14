{ config, lib, pkgs, ... }:

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
    kernelParams = [ "resume=/dev/vg0/swap" ];

    # Latest kernel for best hardware support
    kernelPackages = pkgs.linuxPackages_latest;
  };
}

