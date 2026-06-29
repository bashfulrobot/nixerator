# Brave Origin (nightly) browser module
#
# Uses the local package from ./build/default.nix — a standalone, minimalist
# Brave (Leo/Wallet/Rewards/VPN/News/Tor stripped, Shields kept). nixpkgs has
# no Brave Origin derivation, so it is packaged from the upstream GitHub-release
# zip; version pinned in settings/versions.nix (gui.brave-origin).
#
# Note: Brave Origin only ships Linux artifacts on the nightly channel.
# TODO: Version bump reminder — check for new releases periodically.
# Release URL: https://github.com/brave/brave-browser/releases

{
  globals,
  lib,
  pkgs,
  config,
  versions,
  ...
}:

let
  cfg = config.apps.gui.brave-origin;
  braveOriginPackage = pkgs.callPackage ./build { inherit versions; };

  # User data / config directory for the Origin nightly channel.
  # Best guess based on Brave's naming (regular: Brave-Browser, nightly:
  # Brave-Browser-Nightly). Verify after the first launch and correct if the
  # profile lands elsewhere.
  profileDir = "BraveSoftware/Brave-Origin-Nightly";
in
{
  options = {
    apps.gui.brave-origin.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Brave Origin (minimalist standalone Brave, nightly channel).";
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = [ braveOriginPackage ];

    # 1Password browser integration — Brave Origin is a custom build, so it is
    # not on 1Password's built-in allow-list (unlike regular Brave); register it
    # the same way the Helium module does.
    environment.etc."1password/custom_allowed_browsers".text = lib.mkAfter ''
      brave-origin-nightly
    '';

    # Home Manager user configuration
    home-manager.users.${globals.user.name} = {

      home.file = {
        # Wayland flags, mirroring the regular brave module. On NixOS, Wayland
        # is primarily driven by NIXOS_OZONE_WL (handled in the package wrapper);
        # this file keeps parity with the brave module.
        ".config/brave-origin-nightly-flags.conf".text = ''
          --enable-features=UseOzonePlatform
          --ozone-platform=wayland
          --enable-features=WaylandWindowDecorations
          --ozone-platform-hint=wayland
          --gtk-version=4
          --enable-features=VaapiVideoDecoder
          --enable-gpu-rasterization
        '';

        # 1Password native messaging host for Brave Origin
        ".config/${profileDir}/NativeMessagingHosts/com.1password.1password.json".text = builtins.toJSON {
          name = "com.1password.1password";
          description = "1Password BrowserSupport";
          path = "/run/wrappers/bin/1Password-BrowserSupport";
          type = "stdio";
          allowed_origins = [
            "chrome-extension://hjlinigoblmkhjejkmbegnoaljkphmgo/"
            "chrome-extension://bkpbhnjcbehoklfkljkkbbmipaphipgl/"
            "chrome-extension://gejiddohjgogedgjnonbofjigllpkmbf/"
            "chrome-extension://khgocmkkpikpnmmkgmdnfckapcdkgfaf/"
            "chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/"
            "chrome-extension://dppgmdbiimibapkepcbdbmkaabgiofem/"
          ];
        };
      };

    };

  };
}
