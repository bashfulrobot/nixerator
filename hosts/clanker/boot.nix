_:

{
  # Single-OS VM, legacy BIOS + GRUB on the virtio disk. Regenerate/adjust if
  # the real VM uses UEFI or a different device.
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
    useOSProber = false;
  };
}
