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
        netbootxyz.enable = false;
      };
    };

    # No encryption configured (user preference)
    # ext4 filesystem will mount without password prompt

    # Hibernation disabled for qbert
    kernelParams = [
      "quiet"
      "splash"
    ];

    # Zen kernel for better desktop performance
    # Alternative: pkgs.linuxPackages_latest for newest hardware support
    kernelPackages = pkgs.linuxPackages_zen;

    # Disable nova-core (experimental NVIDIA Rust driver) - not needed for AMD GPU
    # and causes build failures due to missing kernel::firmware Rust bindings
    kernelPatches = [{
      name = "disable-nova-core";
      patch = null;
      structuredExtraConfig = {
        DRM_NOVA = pkgs.lib.kernel.no;
      };
    }];

    # Additional kernel modules for USB and Bluetooth
    kernelModules = [ "usb" "xhci_hcd" "btusb" "bluetooth" ];
  };
}
