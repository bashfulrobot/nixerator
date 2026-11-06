{
  globals,
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  cfg = config.apps.cli.spotify;

  # Spotify script packages using standard pattern
  ncspot-save-playing = pkgs.writeShellApplication {
    name = "ncspot-save-playing";
    runtimeInputs = with pkgs; [
      netcat-openbsd
      jq
      curl
      libnotify
    ];
    text = builtins.readFile ./scripts/ncspot-save-playing.sh;
  };

  # Spicetify packages
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # NCSPOT PIN
  #
  # nixpkgs ships ncspot 1.5.0, which blocks on a blank screen for ~24 s at
  # startup whenever Spotify answers the initial requests with HTTP 429. Two
  # merged-but-unreleased upstream fixes remove that: hrkfdn/ncspot#1886 (the
  # rate-limited startup stall) and #1887 (refetching every liked song on each
  # start, which causes the rate limiting). Both are in main at the rev below.
  #
  # Retirement rule: `ncspotPackage` drops back to the stock package by itself
  # once nixpkgs ships >= 1.5.1 (see `lib.versionOlder` below). Delete this
  # block, `ncspotSrc`, `ncspotPinned` and `ncspotPackage` on the next touch
  # after that happens.
  #
  # rev/version/hashes are fixed, so the derivation is constant and a normal
  # rebuild reuses the store path. Refresh the hashes only when `rev` changes.
  ncspotPin = {
    rev = "91ad4f09c9127f689c2104914cb5fbe1dff512c8"; # main, 2026-11-02
    version = "1.5.0-unstable-2026-11-02";
    srcHash = "sha256-fPqHsGc/+0w9cHce0OejsCYK6pX7ey/gLMiYplSfrJw=";
    cargoHash = "sha256-nmmrXc1TU1j22ffrM+MGenibk3fPZvPHl63/e7dJvWE=";
  };

  ncspotBase = pkgs.ncspot.override { withMPRIS = true; };

  ncspotSrc = pkgs.fetchFromGitHub {
    owner = "hrkfdn";
    repo = "ncspot";
    inherit (ncspotPin) rev;
    hash = ncspotPin.srcHash;
  };

  ncspotPinned = ncspotBase.overrideAttrs (_: {
    inherit (ncspotPin) version cargoHash;
    src = ncspotSrc;
    # buildRustPackage turns the `cargoHash` *argument* into `cargoDeps` before
    # overrideAttrs runs, so overriding cargoHash alone is ignored and the
    # vendor dir still carries 1.5.0's lockfile. Replace it outright.
    cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
      pname = "ncspot";
      inherit (ncspotPin) version;
      src = ncspotSrc;
      hash = ncspotPin.cargoHash;
    };
    # Upstream's Cargo.toml still reads 1.5.0, so `ncspot --version` can never
    # print the "-unstable-" string versionCheckHook greps for.
    preVersionCheck = "version=1.5.0";
  });

  ncspotPackage = if lib.versionOlder pkgs.ncspot.version "1.5.1" then ncspotPinned else ncspotBase;

in
{
  options = {
    apps.cli.spotify.enable = lib.mkEnableOption "spotify players";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      # keep-sorted start case=no numeric=yes
      ncspot-save-playing
      pkgs.spicetify-cli # CLI for customizing Spotify
      # keep-sorted end
    ];

    home-manager.users.${globals.user.name} = {

      # SPICETIFY - Customized Spotify client
      # Note: Spicetify installs Spotify automatically
      programs.spicetify = {
        enable = true;
        enabledExtensions = with spicePkgs.extensions; [
          adblock
          hidePodcasts
          shuffle
        ];
        enabledCustomApps = with spicePkgs.apps; [
          marketplace
        ];
      };

      # NCSPOT
      # Note: Theming is handled by stylix
      programs.ncspot = {
        enable = true;
        package = ncspotPackage;
        settings = {
          shuffle = true;
          gapless = true;
          use_nerdfont = true;
          notify = true;
        };
      };

      # https://github.com/hrkfdn/ncspot/blob/main/doc/users.md#remote-control-ipc
      # running: echo 'save' | nc -W 1 -U $NCSPOT_SOCK
      #  will save the currently playing song to your library in NCSPOT
      home = {
        sessionVariables = {
          NCSPOT_SOCK = "/run/user/1000/ncspot/ncspot.sock";
        };

        # Custom ncspot desktop file with proper window class
        file = {
          ".local/share/applications/ncspot.desktop".text = ''
            [Desktop Entry]
            Name=ncspot
            Comment=ncurses Spotify client
            Exec=kitty --class=ncspot -e ncspot
            Terminal=false
            Type=Application
            Icon=spotify
            Categories=Audio;Music;Player;
            StartupWMClass=ncspot
          '';
        };
      };

      # Hyprland keybind: SUPER+CTRL+S to save the currently playing song.
      # Declared through hyprflake.hyprland.extraLua.
      hyprflake.hyprland.extraLua."ncspot-save" = ''
        hl.bind("SUPER + CTRL + S",
          hl.dsp.exec_cmd("ncspot-save-playing"))
      '';
    };
  };
}
