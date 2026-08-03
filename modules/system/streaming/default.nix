{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.system.streaming;
in
{
  # Sunshine (host) + Moonlight (client) remote desktop/game streaming.
  # Traffic is scoped to the Tailscale tailnet only -- openFirewall stays
  # false and the Sunshine ports (base 47989, offsets per LizardByte's docs:
  # https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2configuration.html#port)
  # are opened on tailscale0 alone, never the LAN/WAN interfaces. Pairing is
  # manual: Moonlight "Add Host" by the peer's Tailscale IP/MagicDNS name,
  # then approve the PIN in Sunshine's web UI (https://<host>:47990).
  options.system.streaming = {
    sunshine.enable = lib.mkEnableOption "Sunshine, a self-hosted game/desktop stream host for Moonlight";

    moonlight.enable = lib.mkEnableOption "Moonlight, the streaming client for a Sunshine host";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.sunshine.enable {
      services.sunshine = {
        enable = true;
        autoStart = true;
        capSysAdmin = true; # required for DRM/KMS screen capture under Wayland/Hyprland
        openFirewall = false; # tailnet-scoped below instead
      };

      # hardware.uinput.enable is already forced on by the sunshine module
      # itself; the primary user still needs to be in the group it creates.
      users.users.${globals.user.name}.extraGroups = [ "uinput" ];

      # The sunshine module defaults services.avahi.enable/publish to true
      # (mkDefault) for LAN mDNS discovery. Streaming here is tailnet-only and
      # Tailscale doesn't forward multicast, so LAN mDNS announcements would
      # be pure unused broadcast surface -- turn them back off.
      services.avahi.enable = lib.mkForce false;

      # Sunshine/GameStream ports, offsets from the base port (47989):
      # TCP -5/0/1/21, UDP 9/10/11/13/21.
      networking.firewall.interfaces.tailscale0 = {
        allowedTCPPorts = [
          47984
          47989
          47990
          48010
        ];
        allowedUDPPorts = [
          47998
          47999
          48000
          48002
          48010
        ];
      };

      # Launcher entry for Sunshine's local admin web UI. Plain browser
      # window rather than the mkWebApp PWA wrapper -- the WebUI is a local
      # self-signed-cert admin console, not a cloud service needing its own
      # persistent profile/extensions.
      home-manager.users.${globals.user.name}.xdg.desktopEntries.sunshine-webui = {
        name = "Sunshine";
        comment = "Configure the Sunshine streaming host";
        exec = "${globals.preferences.browser} --new-window https://localhost:47990";
        icon = "dev.lizardbyte.app.Sunshine";
        categories = [
          "Settings"
          "Network"
        ];
        terminal = false;
      };
    })

    (lib.mkIf cfg.moonlight.enable {
      environment.systemPackages = [ pkgs.moonlight-qt ];
    })
  ];
}
