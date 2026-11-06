{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.apps.cli.soloist;

  # Spotify Soloist: closed-source Spotify Connect player, shipped as a tarball
  # from Spotify's CDN (not GitHub, so it stays out of settings/versions.nix and
  # its update tooling). Builds expire 90 days after build date (exit code 10),
  # so bump `version` and `hash` together at least every 90 days.
  #
  # The download URL carries no version. Spotify replacing the tarball in place
  # makes fetchurl fail with a hash mismatch; refresh the hash with
  #   nix-prefetch-url --type sha256 <url> | xargs nix hash convert --hash-algo sha256 --to sri
  version = "1.3.10";

  soloistBin = pkgs.stdenv.mkDerivation {
    pname = "soloist";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://soloist-builds.spotifycdn.com/soloist_release_x86_64.tar.gz";
      hash = "sha256-+XT/Gs22e9+LbfDvVyM1zQSoQAW11gPLDb6tcoKCFAc=";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    # NEEDED libs: libm + libc (glibc) and libatomic (gcc lib output).
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];

    dontBuild = true;
    sourceRoot = ".";

    installPhase = ''
      install -Dm755 soloist $out/bin/soloist
      install -Dm644 CHANGELOG.md $out/share/doc/soloist/CHANGELOG.md
      install -Dm644 THIRD_PARTY_LICENSES.txt $out/share/doc/soloist/THIRD_PARTY_LICENSES.txt
    '';

    meta = {
      description = "Spotify Soloist, a Spotify Connect device (prebuilt binary)";
      homepage = "https://developer.spotify.com/documentation/soloist";
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };

  # Soloist takes its key only as --api-key. Read it from the secauto gopass
  # store at launch, straight into a variable: never printed, never in the Nix
  # store. The flag still shows in this process's argv (ps) for the session.
  soloistRun = pkgs.writeShellApplication {
    name = "soloist-run";
    runtimeInputs = [
      pkgs.gopass
      soloistBin
    ];
    text = ''
      key="$(gopass show -o -- ${lib.escapeShellArg cfg.gopassEntry})"
      if [ -z "$key" ]; then
        echo "soloist-run: gopass entry ${cfg.gopassEntry} is empty or unreadable" >&2
        exit 1
      fi
      exec soloist \
        --device-name "''${SOLOIST_DEVICE_NAME:-${cfg.deviceName}}" \
        --api-key "$key" \
        "$@"
    '';
  };
in
{
  options.apps.cli.soloist = {
    enable = lib.mkEnableOption "Spotify Soloist (Spotify Connect device) and the soloist-run launcher";

    gopassEntry = lib.mkOption {
      type = lib.types.str;
      default = "automation/spotify-soloist/credential";
      description = "Gopass entry (secauto store) holding the Soloist API key.";
    };

    deviceName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "Spotify Connect device name. Override per run with SOLOIST_DEVICE_NAME.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      soloistBin
      soloistRun
    ];
  };
}
