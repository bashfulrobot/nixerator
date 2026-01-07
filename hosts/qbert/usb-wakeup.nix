_:

{
  # USB wakeup configuration for Logitech MX Mechanical keyboard and MX Master 3 mouse
  # Fixes suspend/hibernate wakeup issues where USB devices cannot wake the system

  # Enable USB wakeup via udev rules
  services.udev.extraRules = ''
    # Enable wakeup for all USB controllers (xhci_hcd)
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="xhci_hcd", ATTR{power/wakeup}="enabled"

    # Enable wakeup for all USB devices
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/wakeup}="enabled"

    # Logitech USB receivers - disable autosuspend and enable wakeup
    # idVendor 046d = Logitech
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{power/wakeup}="enabled"

    # Also enable wakeup for the USB input devices themselves
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", ATTR{power/wakeup}="enabled"
    ACTION=="add", SUBSYSTEM=="input", ATTRS{idVendor}=="046d", ATTR{power/wakeup}="enabled"
  '';

  # Disable USB autosuspend globally
  # This prevents USB dongles from powering down during suspend
  boot.kernelParams = [
    "usbcore.autosuspend=-1"
  ];

  # Optional: If standard S3 suspend still has issues, uncomment to use shallow sleep
  # Shallow sleep (freeze/s2idle) keeps USB controllers powered but uses more battery
  # systemd.sleep.extraConfig = ''
  #   SuspendState=freeze
  #   SuspendMode=
  # '';
}
