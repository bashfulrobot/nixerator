{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.gui.chromium;
  username = globals.user.name;
in
{
  options = {
    apps.gui.chromium.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Chromium web browser with productivity extensions.";
    };
  };

  config = lib.mkIf cfg.enable {

    # System packages - WideVine for DRM streaming content
    environment.systemPackages = with pkgs; [
      (chromium.override { enableWideVine = true; })
    ];

    # Chromium configuration
    programs.chromium = {
      enable = true;

      # Extensions from nixcfg reference
      extensions = [
        "aeblfdkhhhdcdjpifhhbdiojplfjncoa"  # 1Password
        "eimadpbcbfnmbkopoojfekhnkhdbieeh"  # Dark Reader
        "glnpjglilkicbckjpbgcfkogebgllemb"  # Okta
        "kbfnbcaeplbcioakkpcpgfkobkghlhen"  # Grammarly
        "pbmlfaiicoikhdbjagjbglnbfcbcojpj"  # Simplify
        "jldhpllghnbhlbpcmnajkpdmadaolakh"  # Todoist
        "oeopbcgkkoapgobdbedcemjljbihmemj"  # Checker Plus for Mail
        "hkhggnncdpfibdhinjiegagmopldibha"  # Checker Plus for Cal
        "ghbmnnjooekpmoecnnnilnnbdlolhkhi"  # Google Docs Offline
        "pcmpcfapbekmbjjkdalcgopdkipoggdi"  # Markdown downloader
        "bcelhaineggdgbddincjkdmokbbdhgch"  # Mail message URL
        "miancenhdlkbmjmhlginhaaepbdnlllc"  # Copy to clipboard
        "jpfpebmajhhopeonhlcgidhclcccjcik"  # Speed dial
        "ldgfbffkinooeloadekpmfoklnobpien"  # Raindrop
        "bgnkhhnnamicmpeenaelnjfhikgbkllg"  # AdGuard AdBlocker
      ];
    };

    # Home Manager user configuration
    home-manager.users.${username} = {

      programs.chromium = {
        enable = true;

        # Basic Wayland support
        commandLineArgs = [
          "--enable-features=UseOzonePlatform"
          "--ozone-platform=wayland"
          "--enable-features=VaapiVideoDecoder"
          "--enable-gpu-rasterization"
        ];
      };

    };

  };
}
