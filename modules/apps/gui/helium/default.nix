# Helium Browser Module
#
# Uses local package from ../../packages/helium
# Chromium-based privacy-focused browser (beta)
#
# TODO: Version bump reminder - Check for new releases monthly
# Release URL: https://github.com/imputnet/helium-linux/releases
# Current local version: 0.8.1 (see ../../packages/helium/default.nix)
# Note: Helium is currently in beta

{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.gui.helium;
  username = globals.user.name;
in
{
  options = {
    apps.gui.helium.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Helium browser (privacy-focused Chromium-based browser).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Using locally packaged Helium browser
      # See ../../packages/helium/default.nix for version details
      helium
    ];

    # 1Password browser integration
    environment.etc."1password/custom_allowed_browsers".text = lib.mkAfter ''
      helium
    '';

    # Home manager configuration
    home-manager.users.${username} = {
      # 1Password native messaging host for Helium
      home.file.".config/net.imput.helium/NativeMessagingHosts/com.1password.1password.json".text = builtins.toJSON {
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
}
