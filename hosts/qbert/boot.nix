{ pkgs, ... }:

# Boot configuration for qbert with bcachefs (no encryption)

{
  # Boot configuration
  boot = {
    # Use systemd-boot UEFI bootloader
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        consoleMode = "max";  # Ensure Windows and other OSes are found in boot menu
      };
    };

    # No encryption configured (user preference)
    # ext4 filesystem will mount without password prompt

    # Enable hibernation support (with 64GB swap partition)
    # The resumeDevice is configured in disko.nix with resumeDevice = true
    kernelParams = [
      "resume=/dev/disk/by-partlabel/disk-main-swap"
      "quiet"
      "splash"
    ];

    # Zen kernel for better desktop performance
    # Alternative: pkgs.linuxPackages_latest for newest hardware support
    kernelPackages = pkgs.linuxPackages_zen;

    # Additional kernel modules for USB and Bluetooth
    kernelModules = [ "usb" "xhci_hcd" "btusb" "bluetooth" ];
  };
}
