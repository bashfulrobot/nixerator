{ pkgs, ... }:

{
  # libvirt/QEMU guest integration. No virtiofs mount: clanker keeps its own
  # ~/git/nixerator clone like a real host.
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  environment.systemPackages = with pkgs; [
    spice-vdagent
    qemu-utils
  ];
}
