{ config, lib, pkgs, ... }:

{
  # Bootloader configuration - machine-specific
  # This VM uses legacy BIOS with GRUB

  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
    useOSProber = true;
  };
}
