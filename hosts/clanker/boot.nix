_:

{
  # Legacy BIOS GRUB on the virtio disk. Disko creates the EF02 BIOS-boot
  # partition GRUB needs on GPT and sets `boot.loader.grub.devices` to the
  # disk (see disko.nix). We deliberately do NOT set `device` here: the grub
  # module would merge it into `devices`, duplicating /dev/vda and tripping
  # the "duplicated devices in mirroredBoots" assertion.
  boot.loader.grub = {
    enable = true;
    useOSProber = false;
    efiSupport = false;
  };
}
