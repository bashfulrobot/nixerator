_:

# Declarative disk layout for the clanker VM (virtio disk /dev/vda).
# Legacy BIOS + GRUB: a 1 MiB BIOS-boot partition (EF02) holds GRUB's core
# image on GPT, then ext4 root fills the rest. No ESP (pure BIOS). For a UEFI
# VM instead, replace the bios partition with an EF00 ESP mounted at /boot and
# switch boot.nix to systemd-boot.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        bios = {
          size = "1M";
          type = "EF02"; # BIOS boot partition for GRUB on GPT
          priority = 1;
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            mountOptions = [ "noatime" ];
          };
        };
      };
    };
  };
}
