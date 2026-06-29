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
  # Confirmed against the AUR brave-origin-nightly launcher, which exports
  # CHROME_USER_DATA_DIR=~/.config/BraveSoftware/Brave-Origin-Nightly.
  profileDir = "BraveSoftware/Brave-Origin-Nightly";

  # Chrome Web Store update endpoint (Brave proxies the CWS).
  cwsUpdateUrl = "https://clients2.google.com/service/update2/crx";

  # Extensions auto-installed via the ExtensionInstallForcelist managed policy.
  # Curated to mirror the google-chrome "Default" profile so the daily-driver
  # set carries over to Brave Origin. IDs are Chrome Web Store extension IDs.
  # To prune, drop the line; to make them user-removable instead of pinned,
  # switch the policy below to ExtensionSettings with installation_mode
  # "normal_installed".
  defaultExtensions = [
    "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password – Password Manager
    "apadglapdamclpaedknbefnbcajfebgh" # Smart Mute
    "appjbedfhcmpknanmbndpojcllfaemal" # Zoom Closer
    "bcelhaineggdgbddincjkdmokbbdhgch" # Mail message URL
    "bnjglocicdkmhmoohhfkfkbbkejdhdgc" # FlowCrypt: Encrypt Gmail with PGP
    "cidlcjdalomndpeagkjpnefhljffbnlo" # Toggle JavaScript
    "ecabifbgmdmgdllomnfinbmaellmclnh" # Reader View
    "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
    "fcoeoabgfenejglbffodgkkbkcdhcgfn" # Claude
    "fdpohaocaechififmbbbbbknoalclacl" # GoFullPage - Full Page Screen Capture
    "fggkaccpbmombhnjkjokndojfgagejfb" # Tactiq: AI note taker
    "gbkeegbaiigmenfmjfclcdgdpimamgkj" # Office Editing for Docs, Sheets & Slides
    "gciegpagokgfonmlmdecellbnhgebdlf" # Glinks go links
    "glnpjglilkicbckjpbgcfkogebgllemb" # Okta Browser Plugin
    "hkhggnncdpfibdhinjiegagmopldibha" # Checker Plus for Google Calendar
    "imohnlganmafcmidafklgkgfgaagiohn" # yet another speed dial
    "jegbdohdgebjljoljfeinojeobdabpjo" # Redirector
    "jjghhkepijgakdammjldcbnjehfkfmha" # Salesforce
    "jldhpllghnbhlbpcmnajkpdmadaolakh" # Todoist for Chrome
    "jpmkfafbacpgapdghgdpembnojdlgkdl" # AWS Extend Switch Roles
    "kgjfgplpablkjnlkjmjdecgdpfankdle" # Zoom Chrome Extension
    "khncfooichmfjbepaaaebmommgaepoid" # Unhook - Remove YouTube Recommended & Shorts
    "ldjkgaaoikpmhmkelcgkgacicjfbofhh" # Instapaper
    "lodbfhdipoipcjmlebjbgmmgekckhpfb" # Harper - Private Grammar Checker
    "mbodbfopnnihkmkhcojmieknngpcalhf" # Tabs auto close
    "mdjildafknihdffpkfmmpnpoiajfjnjd" # Consent-O-Matic
    "miancenhdlkbmjmhlginhaaepbdnlllc" # Copy URL To Clipboard
    "oeopbcgkkoapgobdbedcemjljbihmemj" # Checker Plus for Gmail
    "pbmlfaiicoikhdbjagjbglnbfcbcojpj" # Simplify Gmail
    "pppfmbnpgflleackdcojndfgpiboghga" # Checker Plus for Google Drive
  ];
in
{
  options = {
    apps.gui.brave-origin.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Brave Origin (minimalist standalone Brave, nightly channel).";
    };

    apps.gui.brave-origin.extensions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultExtensions;
      example = [ "aeblfdkhhhdcdjpifhhbdiojplfjncoa" ];
      description = ''
        Chrome Web Store extension IDs to auto-install into Brave Origin via the
        ExtensionInstallForcelist managed policy (written to
        /etc/brave/policies/managed/). Defaults to the set mirrored from the
        google-chrome profile. Set to [ ] to disable managed extensions.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    environment = {
      systemPackages = [ braveOriginPackage ];

      etc = {
        # Declaratively auto-install extensions via Brave's managed-policy
        # directory (the binary reads /etc/brave/policies). This is the durable
        # answer to Brave Sync not reliably carrying extensions across devices.
        "brave/policies/managed/extensions.json" = lib.mkIf (cfg.extensions != [ ]) {
          text = builtins.toJSON {
            ExtensionInstallForcelist = map (id: "${id};${cwsUpdateUrl}") cfg.extensions;
          };
        };

        # 1Password browser integration — Brave Origin is a custom build, so it
        # is not on 1Password's built-in allow-list (unlike regular Brave);
        # register it the same way the Helium module does.
        "1password/custom_allowed_browsers".text = lib.mkAfter ''
          brave-origin-nightly
        '';
      };
    };

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
