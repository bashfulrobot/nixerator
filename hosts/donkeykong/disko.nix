_:

# Disko configuration for donkeykong
# ext4 with LUKS encryption - simple and proven
# 32GB swap for hibernation support with 32GB RAM

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-SAMSUNG_MZVLC1T0HFLU-00BLL_S7SDNF0Y302997";
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

            # Encrypted root partition
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                # Prompt for password during boot
                # For key file: passwordFile = "/tmp/secret.key";
                settings = {
                  allowDiscards = true; # Important for SSD TRIM support
                  bypassWorkqueues = true; # Better SSD performance
                };
                content = {
                  type = "lvm_pv";
                  vg = "vg0";
                };
              };
            };
          };
        };
      };
    };

    # LVM volume group on encrypted partition
    lvm_vg = {
      vg0 = {
        type = "lvm_vg";
        lvs = {
          # Swap volume (for hibernation with 32GB RAM)
          swap = {
            size = "32G";
            content = {
              type = "swap";
            };
          };

          # Root volume (includes /home, gets remaining space)
          root = {
            size = "100%FREE";
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
}

