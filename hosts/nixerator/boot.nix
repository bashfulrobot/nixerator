{ config, lib, pkgs, ... }:

{
  # Bootloader configuration - machine-specific
  # This VM uses legacy BIOS with GRUB

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
  boot.loader.grub.useOSProber = true;
}
