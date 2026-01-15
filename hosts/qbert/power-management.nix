{ config, lib, pkgs, ... }:

# Power management configuration for qbert
# AMD GPU-specific workarounds for suspend/hibernate bugs
# Disables suspend/hibernate via hyprflake power management options

{
  # Override hyprflake power management for qbert
  # Disables suspend/hibernate due to AMD GPU bugs
  hyprflake = {
    # Disable suspend timeout in hypridle (lock + DPMS only)
    desktop.idle.suspendTimeout = 0;

    # Disable suspend and hibernate system-wide
    system.power.sleep = {
      allowSuspend = false;
      allowHibernation = false;
    };

    # Logind configuration (lock on lid close, power button shuts down)
    system.power.logind = {
      handleLidSwitch = "lock";
      handlePowerKey = "poweroff";
    };
  };

  # AMD GPU-specific kernel parameters and configuration
  # Required workaround for "amdgpu: suspend of IP block <smu> failed -22" error
  boot.kernelParams = [
    # Disable AMD GPU runtime power management to prevent SMU failures
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
}
