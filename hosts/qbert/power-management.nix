{ config, lib, pkgs, ... }:

# Power management configuration for qbert
# Disables suspend/hibernate to avoid AMD GPU power state bugs
# Uses lock + DPMS only (managed by hypridle from hyprflake)

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

    # Force deep sleep (S3) mode at kernel level (if suspend is manually triggered)
    # Prevents fallback to unreliable s2idle mode with AMD GPUs
    "mem_sleep_default=deep"
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

  # Systemd logind configuration - disable suspend/hibernate
  # Idle behavior managed by hypridle (lock + DPMS only)
  services.logind = {
    settings = {
      Login = {
        HandleLidSwitch = "lock"; # Lock screen on lid close (if applicable)
        HandlePowerKey = "poweroff"; # Power button shuts down
        IdleAction = "ignore"; # Hypridle manages idle timeout
        IdleActionSec = "0"; # Disabled
      };
    };
  };

  # Disable suspend and hibernate system-wide
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';
}
