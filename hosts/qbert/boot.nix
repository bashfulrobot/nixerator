{ config, lib, pkgs, ... }:

# Boot configuration for qbert with bcachefs (no encryption)

{
  # Use systemd-boot UEFI bootloader
  boot.loader = {
    efi.canTouchEfiVariables = true;
    systemd-boot = {
      enable = true;
      consoleMode = "max";  # Ensure Windows and other OSes are found in boot menu
      configurationLimit = 5;  # Limit generations to prevent boot partition from filling up
    };
  };

  # Enable bcachefs support
  boot.supportedFilesystems = [ "bcachefs" ];

  # No encryption configured (user preference)
  # Bcachefs filesystem will mount without password prompt

  # Enable hibernation support (with 64GB swap partition)
  # The resumeDevice is configured in disko.nix with resumeDevice = true
  boot.kernelParams = [
    "resume=/dev/disk/by-partlabel/disk-main-swap"
    "quiet"
    "splash"
  ];

  # Zen kernel for better desktop performance
  # Alternative: pkgs.linuxPackages_latest for newest hardware support
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Additional kernel modules for USB and Bluetooth
  boot.kernelModules = [ "usb" "xhci_hcd" "btusb" "bluetooth" ];
}
