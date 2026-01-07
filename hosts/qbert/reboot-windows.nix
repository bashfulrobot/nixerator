{ pkgs, ... }:

# Desktop entry for rebooting to Windows on qbert
# Windows is installed on nvme0n1 (Samsung 500GB)
# Linux is on nvme1n1 (WD 1TB SN850X)

{
  # Create desktop entry for rebooting to Windows
  # This will appear in application menus under System
  environment.systemPackages = [
    (pkgs.makeDesktopItem {
      name = "reboot-windows";
      desktopName = "Reboot to Windows";
      comment = "Reboot the computer and boot into Windows";
      # Note: The boot loader entry name may need adjustment based on actual EFI entries
      # Run 'bootctl list' to see available entries and update if needed
      # Common entry names: auto-windows, windows, Microsoft, auto-efi-microsoft
      exec = "${pkgs.systemd}/bin/systemctl reboot --boot-loader-entry=auto-windows";
      icon = "system-reboot";
      terminal = false;
      type = "Application";
      categories = [ "System" ];
    })
  ];
}
