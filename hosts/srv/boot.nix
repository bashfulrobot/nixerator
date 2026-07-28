_:

{
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Kernel default-enables DAMON_STAT (passive memory-access monitor); nothing on
  # srv consumes its telemetry and it burns ~20% of one core continuously on this
  # 15W mobile chip already loaded by the darkstar Talos VMs. Disable it.
  boot.kernelParams = [ "damon_stat.enabled=0" ];
}
