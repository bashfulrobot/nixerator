{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.apps.cli.media-rename;

  runtimeDeps = [
    pkgs.filebot
    pkgs.rsync
    pkgs.openssh
  ];

  # Shared shape: rsync new files from the seedbox into a staging dir under
  # the media root, rename/organize them with filebot, then clear staging.
  # filebot runs as the invoking user directly against the local media tree
  # (already on srv's own disk -- no Docker, no NFS round-trip, no chown
  # step needed since files land already owned by whoever ran the command).
  mkRenameScript =
    {
      name,
      seedboxPath,
      stagingDir,
      db,
      outputDir,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = runtimeDeps;
      text = ''
        MEDIA_ROOT="${cfg.mediaRoot}"
        STAGING="$MEDIA_ROOT/_staging/${stagingDir}"

        echo "Getting Files"
        cd "$STAGING"
        rsync --progress -avze ssh "${cfg.seedboxHost}:${seedboxPath}" ./

        echo "Renaming Files"
        filebot -r -rename "$STAGING" --format "{plex}" --db ${db} --lang en \
          --action copy --conflict override --output "$MEDIA_ROOT/${outputDir}" -non-strict

        echo "Cleaning up staging files"
        find "$STAGING" -mindepth 1 -delete
      '';
    };

  dlm = mkRenameScript {
    name = "dlm";
    seedboxPath = "/media/sdi1/msgedme/private/deluge/data/dlm/";
    stagingDir = "process-m";
    db = "themoviedb";
    outputDir = "Movies";
  };

  dltv = mkRenameScript {
    name = "dltv";
    seedboxPath = "/media/sdi1/msgedme/private/deluge/data/dl/";
    stagingDir = "process";
    db = "thetvdb";
    outputDir = "TV Shows";
  };
in
{
  options.apps.cli.media-rename = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install dlm/dltv: pull new movies/TV from the seedbox and rename them
        into the Jellyfin library with filebot. Replaces the old
        Docker-based (rednoah/filebot) versions of these scripts.
      '';
    };

    seedboxHost = lib.mkOption {
      type = lib.types.str;
      default = "msgedme@prometheus.feralhosting.com";
      description = "SSH target for the seedbox rsync pull.";
    };

    mediaRoot = lib.mkOption {
      type = lib.types.str;
      default = "/home/dustin/data-disk/media";
      description = ''
        Root of the local media tree. Expects `$mediaRoot/_staging/process`
        and `$mediaRoot/_staging/process-m` to already exist.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      dlm
      dltv
    ];
  };
}
