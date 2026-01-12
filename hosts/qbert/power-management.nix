{ config, lib, pkgs, ... }:

# Power management workarounds for qbert's AMD Navi GPU suspend bugs
# This module fixes the AMD GPU SMU suspend failure and USB wakeup issues
# specific to this system's hardware (RX 6800/6900 XT + Logitech wireless peripherals)

{
  # Kernel boot parameters
  boot.kernelParams = [
    # AMD GPU suspend bug workaround
    # Fixes "amdgpu: suspend of IP block <smu> failed -22" error
    # This disables AMD GPU runtime power management to prevent SMU failures
    "amdgpu.runpm=0"

    # USB autosuspend disabled globally
    # Prevents USB dongles from powering down during suspend
    "usbcore.autosuspend=-1"
  ];

  # Kernel modules configuration for AMD GPU
  boot.extraModprobeConfig = ''
    # AMD GPU power management workaround
    options amdgpu runpm=0
  '';

  # USB wakeup udev rules
  # Fixed to target correct sysfs paths (devices, not interfaces)
  services.udev.extraRules = ''
    # Enable wakeup for USB controllers (correct sysfs path)
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="xhci_hcd", TEST=="power/wakeup", ATTR{power/wakeup}="enabled"

    # Enable wakeup for USB devices (not interfaces)
    ACTION=="add", SUBSYSTEM=="usb", ATTR{devpath}=="*", TEST=="power/wakeup", ATTR{power/wakeup}="enabled"

    # Logitech wireless receivers - keep powered and enable wakeup
    # idVendor 046d = Logitech
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", TEST=="power/wakeup", ATTR{power/wakeup}="enabled"
  '';

  # Systemd sleep configuration
  systemd.sleep.extraConfig = ''
    # Use deep sleep (S3) for better power savings
    SuspendMode=deep
    HibernateMode=platform shutdown
  '';

  # Post-resume script to ensure display wakes up after AMD GPU suspend
  systemd.services.post-resume-amd-gpu = {
    description = "Post-Resume Actions for AMD GPU";
    wantedBy = [ "suspend.target" ];
    after = [ "suspend.target" ];
    serviceConfig = {
      Type = "oneshot";
      # Restart hyprpaper after resume to fix potential display issues
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/sleep 1 && ${pkgs.systemd}/bin/systemctl --user -M $(${pkgs.procps}/bin/pgrep -u $USER Hyprland | ${pkgs.coreutils}/bin/head -1)@.host restart hyprpaper.service || true'";
    };
  };
}
