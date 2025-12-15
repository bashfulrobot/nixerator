_:

# Disko configuration for qbert
# ext4 without encryption - simple and reliable
# 64GB swap for hibernation support with 64GB RAM
#
# Drive: nvme-WDS100T3X0C-00SJG0_210611801063 (1TB WD SN850X, nvme0n1)
# This will REPLACE the current Ubuntu installation
# Windows drive (nvme1n1 Samsung 500GB) is NOT touched

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WDS100T3X0C-00SJG0_210611801063";
        content = {
          type = "gpt";
          partitions = {
            # ESP boot partition (required for UEFI)
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            # Swap partition (for hibernation with 64GB RAM)
            swap = {
              size = "64G";
              content = {
                type = "swap";
                discardPolicy = "both";
                resumeDevice = true; # Enable hibernation resume
              };
            };

            # Root partition (ext4, remaining space ~866GB)
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
    };
  };
}
