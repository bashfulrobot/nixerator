{ ... }:

# Shure MV7 audio profile fix (qbert-specific hardware).
#
# The MV7 USB mic exposes its headphone-monitor jack as a playback sink. Its
# card was defaulting to the IEC958 (S/PDIF-framed digital) output profile,
# which sends digital frames the headphone DAC cannot play -- so any client
# using the default sink (notably jellyfin-mpv-shim's mpv, which just follows
# the PipeWire default sink) produced no audible audio. The card also offers an
# analog PCM profile that already outranks IEC958 by priority; a stale
# ~/.local/state/wireplumber pin was forcing the digital one.
#
# This rule forces the MV7 card onto its analog profile and disables ACP
# auto-profile selection, so the broken IEC958 sink is never created and no
# stale user-state can re-select it. It matches only the MV7 device name, so it
# is inert on any host without that device (e.g. donkeykong).
{
  services.pipewire.wireplumber.extraConfig."51-mv7-analog" = {
    "monitor.alsa.rules" = [
      {
        matches = [ { "device.name" = "alsa_card.usb-Shure_Inc_Shure_MV7-00"; } ];
        actions.update-props = {
          "device.profile" = "output:analog-stereo+input:mono-fallback";
          "api.acp.auto-profile" = false;
        };
      }
    ];
  };
}
