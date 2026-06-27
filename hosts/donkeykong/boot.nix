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
        allowDiscards = true; # Important for SSD TRIM support
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
      "mitigations=off" # Disable Spectre/Meltdown mitigations for single-user workstation
    ];

    # XanMod kernel: performance/low-latency desktop kernel (same tier as zen).
    # Switched off linuxPackages_zen on 2026-06-27 because zen 7.0.12 hit a kernel
    # x86 install bug (image lands as $out/vmlinuz not $out/bzImage, failing the
    # systemd-boot kernelFile check) on nixos-unstable >= e73de5b. xanmod builds
    # bzImage cleanly from cache; revisit zen once upstream fixes the install path.
    kernelPackages = pkgs.linuxPackages_xanmod_latest;
  };
}
