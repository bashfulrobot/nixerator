{ ... }:

# Disko configuration for qbert
# bcachefs without encryption, with compression
# Subvolumes for better snapshot management
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
            # ESP boot partition (unencrypted, required for UEFI)
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
            # Placed before bcachefs to ensure consistent partition layout
            swap = {
              size = "64G";
              content = {
                type = "swap";
                discardPolicy = "both";
                resumeDevice = true; # Enable hibernation resume
              };
            };

            # Bcachefs partition (remaining space ~866GB)
            bcachefs = {
              size = "100%";
              content = {
                type = "bcachefs";
                name = "qbert_root";
                # No encryption (user preference)
                # LZ4 compression for performance and space savings
                extraArgs = [
                  "--discard"
                  "--compression=lz4"
                  "--background_compression=lz4"
                ];
                subvolumes = {
                  # Root subvolume
                  "/subvolumes/root" = {
                    mountpoint = "/";
                    mountOptions = [ "noatime" ];
                  };

                  # Home subvolume (easier to snapshot separately)
                  "/subvolumes/home" = {
                    mountpoint = "/home";
                    mountOptions = [ "noatime" ];
                  };

                  # Nix store subvolume (can be excluded from snapshots)
                  "/subvolumes/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "noatime" ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
