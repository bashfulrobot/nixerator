{ config, lib, pkgs, ... }:

# Power management workarounds for qbert's AMD Navi GPU suspend bugs
# This module fixes the AMD GPU SMU suspend failure and USB wakeup issues
# specific to this system's hardware (RX 6800/6900 XT + Logitech wireless peripherals)
# Uses hibernate instead of suspend to avoid AMD GPU power state bugs

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

  # Systemd logind configuration - use hibernate instead of suspend for idle timeout
  # Hibernate avoids AMD GPU power state bugs and works reliably with WOL
  services.logind = {
    settings = {
      Login = {
        HandleLidSwitch = "hibernate"; # Hibernate on lid close
        HandlePowerKey = "hibernate";
        IdleAction = "hibernate";
        IdleActionSec = "30min";
      };
    };
  };

  # Systemd sleep configuration
  # Note: SuspendMode was removed in systemd 254+, use SuspendState instead
  systemd.sleep.extraConfig = ''
    # Use mem (deep sleep/S3) for better power savings (if suspend is manually triggered)
    # This corresponds to /sys/power/state "mem" which uses the mode from /sys/power/mem_sleep
    SuspendState=mem
    HibernateState=disk
  '';

  # Post-resume script to ensure display wakes up after AMD GPU suspend/hibernate
  systemd.services.post-resume-amd-gpu = {
    description = "Post-Resume Actions for AMD GPU";
    wantedBy = [ "suspend.target" "hibernate.target" ];
    after = [ "suspend.target" "hibernate.target" ];
    serviceConfig = {
      Type = "oneshot";
      # Force DPMS on to wake displays after resume
      ExecStart = "${pkgs.bash}/bin/bash -c '" +
        "# Wait for system to stabilize\n" +
        "${pkgs.coreutils}/bin/sleep 2\n" +
        "# Find Hyprland socket and force DPMS on\n" +
        "for socket_dir in /run/user/*/hypr/*/; do\n" +
        "  socket=\"$socket_dir.socket.sock\"\n" +
        "  if [ -S \"$socket\" ]; then\n" +
        "    HYPR_USER=$(${pkgs.coreutils}/bin/stat -c %U \"$socket\")\n" +
        "    HYPR_SIGNATURE=$(${pkgs.coreutils}/bin/basename \"$(${pkgs.coreutils}/bin/dirname \"$socket\")\")\n" +
        "    sudo -u \"$HYPR_USER\" HYPRLAND_INSTANCE_SIGNATURE=\"$HYPR_SIGNATURE\" ${pkgs.hyprland}/bin/hyprctl dispatch dpms on || true\n" +
        "    # Restart hyprpaper for this user\n" +
        "    ${pkgs.systemd}/bin/systemctl --user -M \"$HYPR_USER\"@.host restart hyprpaper.service || true\n" +
        "  fi\n" +
        "done\n" +
        "# Force display re-detection at kernel level (card1 for AMD GPU)\n" +
        "for port in /sys/class/drm/card1-*/status; do\n" +
        "  [ -f \"$port\" ] && echo detect > \"$port\" 2>/dev/null || true\n" +
        "done\n" +
        "'";
    };
  };
}
