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
        consoleMode = "max"; # Ensure Windows and other OSes are found in boot menu
      };
    };

    # No encryption configured (user preference)
    # ext4 filesystem will mount without password prompt

    # Hibernation disabled for qbert
    kernelParams = [
      "quiet"
      "splash"
      "mitigations=off" # Disable Spectre/Meltdown mitigations for single-user workstation
    ];

    # XanMod kernel: performance/low-latency desktop+gaming kernel (same tier as
    # zen). Switched off linuxPackages_zen on 2026-06-27 because zen 7.0.12 hit a
    # kernel x86 install bug (image lands as $out/vmlinuz not $out/bzImage,
    # failing the systemd-boot kernelFile check) on nixos-unstable >= e73de5b.
    # xanmod builds bzImage cleanly from cache; revisit zen once upstream fixes
    # the install path. Alternative: pkgs.linuxPackages_latest for newest mainline.
    kernelPackages = pkgs.linuxPackages_xanmod_latest;

    # Additional kernel modules for USB and Bluetooth
    kernelModules = [
      "usb"
      "xhci_hcd"
      "btusb"
      "bluetooth"
    ];
  };

  system.resilient-boot.enable = true;
}
