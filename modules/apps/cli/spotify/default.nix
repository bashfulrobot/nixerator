{ globals, pkgs, lib, config, inputs, ... }:

let
  cfg = config.apps.cli.spotify;
  username = globals.user.name;

  # Spotify script packages using standard pattern
  spotifyScripts = with pkgs; [
    (writeShellScriptBin "ncspot-save-playing" (builtins.readFile ./scripts/ncspot-save-playing.sh))
  ];

  # Spicetify packages
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};

in
{
  options = {
    apps.cli.spotify.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable spotify players.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # keep-sorted start case=no numeric=yes
      curl
      jq          # for JSON parsing
      libnotify   # for notify-send
      # Script runtime dependencies
      netcat-gnu  # for nc command
      spicetify-cli  # CLI for customizing Spotify
      # keep-sorted end
    ] ++ spotifyScripts;


    home-manager.users.${username} = {

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
        package = pkgs.ncspot.override { withMPRIS = true; };
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
    };
  };
}

