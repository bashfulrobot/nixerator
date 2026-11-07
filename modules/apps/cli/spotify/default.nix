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

  # NCSPOT PIN (fork: github.com/bashfulrobot/ncspot, branch dk)
  #
  # Built from our fork, not nixpkgs' ncspot and not upstream. The fork is
  # upstream main 91ad4f0 plus four commits:
  #   - its own Spotify client ID, so ncspot has its own API quota instead of
  #     sharing upstream's ID with every other user, which is what produced the
  #     constant HTTP 429s,
  #   - a fixed redirect port (8888) for the Web API login,
  #   - a justfile for fork maintenance,
  #   - Spotify-owned and followed playlists (Discover Weekly, Release Radar,
  #     Daily Mix) read through the librespot session instead of the Web API. A
  #     dev-mode Spotify app cannot read those playlists over the Web API, so
  #     with our own client ID they are invisible without this. It adds the
  #     librespot-metadata and protobuf crates, which is why `cargoHash`
  #     changed with this bump.
  # The upstream base already carries hrkfdn/ncspot#1886 (blank screen for
  # ~24 s at startup when rate limited) and #1887 (refetching every liked song
  # on each start), neither of which is in a release.
  #
  # The override is unconditional: the client-ID patch exists only in the fork,
  # so no nixpkgs version replaces it.
  #
  # Retirement rule: drop the pin only when upstream ncspot lets a user
  # configure their own client ID. A new upstream release is not enough.
  #
  # Full background, and how to move the pin: `.claude/docs/ncspot-pin.md`.
  #
  # rev/version/hashes are fixed, so the derivation is constant and a normal
  # rebuild reuses the store path. Refresh the hashes only when `rev` changes.
  ncspotPin = {
    owner = "bashfulrobot";
    repo = "ncspot";
    rev = "46e2bdfbb5f46a71e19fc66a8df45f25af86a467"; # tag v1.5.0-dk3
    version = "1.5.0-dk3";
    srcHash = "sha256-NuHJZyy0Q/0UHZZPEz+xOV7w08FSMFZ5HkUECcN5D7g=";
    cargoHash = "sha256-K2dvHfZXzShburRIkBadybgiNAPIhZJF8P4pmP/LEF0=";
  };

  ncspotSrc = pkgs.fetchFromGitHub {
    inherit (ncspotPin) owner repo rev;
    hash = ncspotPin.srcHash;
  };

  ncspotPackage = (pkgs.ncspot.override { withMPRIS = true; }).overrideAttrs (_: {
    inherit (ncspotPin) version cargoHash;
    src = ncspotSrc;
    # buildRustPackage turns the `cargoHash` *argument* into `cargoDeps` before
    # overrideAttrs runs, so overriding cargoHash alone is ignored and the
    # vendor dir still carries nixpkgs' 1.5.0 lockfile. Replace it outright.
    cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
      pname = "ncspot";
      inherit (ncspotPin) version;
      src = ncspotSrc;
      hash = ncspotPin.cargoHash;
    };
    # The fork's Cargo.toml still reads 1.5.0, so `ncspot --version` can never
    # print the "-dk2" suffix versionCheckHook greps for.
    preVersionCheck = "version=1.5.0";
  });

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
      # running: echo 'save current' | nc -W 1 -U $NCSPOT_SOCK
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
