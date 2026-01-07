_:

{
  # Comprehensive wakeup configuration for laptop
  # Fixes suspend/hibernate wakeup issues for both built-in and external devices
  # Enables wakeup from: built-in keyboard/touchpad, external USB devices

  # Enable wakeup via udev rules
  services.udev.extraRules = ''
    # Enable wakeup for PS/2 devices (built-in keyboard/touchpad on most laptops)
    ACTION=="add", SUBSYSTEM=="serio", ATTR{power/wakeup}="enabled"
    ACTION=="add", SUBSYSTEM=="i2c", ATTR{power/wakeup}="enabled"

    # Enable wakeup for lid switch and power button
    ACTION=="add", SUBSYSTEM=="acpi", KERNEL=="LNXPWRBN:*", ATTR{power/wakeup}="enabled"
    ACTION=="add", SUBSYSTEM=="acpi", KERNEL=="PNP0C0D:*", ATTR{power/wakeup}="enabled"

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

  # Use shallow sleep (freeze/s2idle) for better wake reliability on laptops
  # Shallow sleep keeps more devices powered and is more reliable for problematic laptops
  # Trade-off: slightly higher battery usage during sleep
  systemd.sleep.extraConfig = ''
    SuspendState=freeze
    SuspendMode=
  '';
}
