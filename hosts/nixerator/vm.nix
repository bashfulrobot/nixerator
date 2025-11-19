{ config, pkgs, ... }:

{
  # VM-specific configuration for libvirt/QEMU
  # Remove or comment out this import when installing to bare metal

  # Virtiofs filesystem support for VM shared folders
  boot.kernelModules = [ "virtiofs" ];

  # Shared folder from host via virtiofs
  # This mounts the host's shared folder into the VM
  # In libvirt XML, this corresponds to a filesystem element with:
  # <source dir="/path/on/host"/>
  # <target dir="mount_nixerator"/>
  fileSystems."/home/dustin/dev/nix/nixerator" = {
    device = "mount_nixerator";
    fsType = "virtiofs";
    options = [ "rw" ];
  };

  # QEMU Guest Agent for better VM integration
  services.qemuGuest.enable = true;

  # Spice VD Agent for clipboard sharing and dynamic resolution
  services.spice-vdagentd.enable = true;

  # Additional VM utilities
  environment.systemPackages = with pkgs; [
    spice-vdagent  # Spice agent for better display/clipboard
    qemu-utils     # QEMU utilities for VM management
  ];

  # Enable automatic login for VM testing (optional - remove for security)
  # services.xserver.displayManager.autoLogin.enable = true;
  # services.xserver.displayManager.autoLogin.user = "dustin";
}
