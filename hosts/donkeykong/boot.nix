{ config, lib, pkgs, ... }:

# Boot configuration for donkeykong with LUKS encryption

{
  # Use systemd-boot UEFI bootloader
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # LUKS encryption support
  boot.initrd = {
    # Enable LUKS support in initrd
    luks.devices."cryptroot" = {
      # The device will be set up by disko
      # This just enables kernel support and prompts for password
      preLVM = true;
      allowDiscards = true;  # Important for SSD TRIM support
    };

    # Load kernel modules needed for encryption early
    # Crypto modules (AES, SIMD) are auto-loaded by kernel as needed
    availableKernelModules = [
      "dm-crypt"      # Device mapper crypto
      "dm-mod"        # Device mapper
    ];
  };

  # Enable hibernation support (with 32GB swap)
  boot.resumeDevice = "/dev/vg0/swap";
  boot.kernelParams = [ "resume=/dev/vg0/swap" ];

  # Latest kernel for best hardware support
  boot.kernelPackages = pkgs.linuxPackages_latest;
}

