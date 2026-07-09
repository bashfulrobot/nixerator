{
  pkgs,
  config,
  lib,
  versions,
  globals,
  ...
}:
let
  cfg = config.apps.cli.aha-fr-report;

  # Same custom-built package the gws module itself uses (not in nixpkgs).
  # Referencing pkgs.callPackage here rather than depending on
  # apps.cli.gws.enable keeps this module self-contained: it works whether
  # or not gws happens to be separately enabled on a given host.
  gws = pkgs.callPackage ../gws/build { inherit versions; };

  # The whole package directory (vendor/, scripts/, assets/, customers.txt)
  # copied into one Nix store path as-is, so the scripts' own relative-path
  # resolution ($(dirname "$0")-style, matching the aha skill's own scripts)
  # keeps working unchanged rather than needing per-file substituteInPlace.
  src = pkgs.runCommand "aha-fr-report-src" { } ''
    mkdir -p "$out"
    cp -r ${./vendor} "$out/vendor"
    cp -r ${./scripts} "$out/scripts"
    cp -r ${./assets} "$out/assets"
    cp ${./customers.txt} "$out/customers.txt"
    chmod -R u+w "$out"
    chmod +x "$out"/scripts/*.sh "$out"/scripts/*.py "$out"/vendor/*.sh
  '';

  jqBin = "${pkgs.jq}/bin/jq";

  runtimeDeps = [
    pkgs.jq
    pkgs.python3
    pkgs.wkhtmltopdf
    pkgs.curl
    pkgs.sqlite
    gws
  ];

  # Loads AHA_API_TOKEN from the off-store secrets file at runtime (same
  # pattern as restic's backup-mgr / secretsFile, see
  # modules/apps/cli/restic/default.nix) so the token never enters the
  # world-readable /nix/store, then execs the real pipeline script.
  loadTokenAndExec = target: ''
    secrets_file="${cfg.secretsFile}"
    if [[ ! -r "$secrets_file" ]]; then
      echo "aha-fr-report: secrets file $secrets_file is missing or unreadable." >&2
      echo "Run 'just render-secrets' (or push from a peer) and retry." >&2
      exit 1
    fi
    token="$(${jqBin} -r '.aha.apiToken // empty' "$secrets_file")"
    if [[ -z "$token" ]]; then
      echo "aha-fr-report: no .aha.apiToken in $secrets_file." >&2
      exit 1
    fi
    export AHA_API_TOKEN="$token"
    exec "${src}/scripts/${target}" "$@"
  '';

  aha-fr-report-one = pkgs.writeShellApplication {
    name = "aha-fr-report-one";
    runtimeInputs = runtimeDeps;
    text = loadTokenAndExec "customer-fr-report.sh";
  };

  aha-fr-report = pkgs.writeShellApplication {
    name = "aha-fr-report";
    runtimeInputs = runtimeDeps;
    text = loadTokenAndExec "run-all.sh";
  };
in
{
  options.apps.cli.aha-fr-report = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install aha-fr-report / aha-fr-report-one: per-customer Aha! feature
        request reports (internal Google Sheet + Kong-branded PDF snapshot)
        written into <Customer>/CS/FRs in the Customers shared drive.
      '';
    };

    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = "${globals.user.homeDirectory}/.config/nixos-secrets/secrets.json";
      description = ''
        Path to the off-store JSON secrets file (rendered by render-secrets)
        that aha-fr-report reads `.aha.apiToken` from at runtime.
      '';
    };

    schedule = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Run aha-fr-report (all customers.txt entries) on a systemd user
          timer bound to the desktop session, so gws can use the same
          session keyring interactive use already relies on. Only makes
          sense on a workstation host with a graphical session and
          home-manager.
        '';
      };

      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 07:00:00";
        description = "Systemd timer OnCalendar schedule.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        aha-fr-report-one
        aha-fr-report
      ];
    })

    (lib.mkIf (cfg.enable && cfg.schedule.enable) {
      # A user-session timer, not a system one: it runs inside the desktop
      # session so gws can reach the already-unlocked session keyring, the
      # same one interactive `aha-fr-report-one` calls already use. No
      # separate headless credential (no MATERIALIZE copy, no file-backend
      # keyring) needed. Trade-off: it only fires while logged into a
      # graphical session. Persistent = true means a run missed because the
      # machine was asleep/logged-out at OnCalendar fires as soon as the
      # session comes back up, not skipped outright.
      home-manager.users.${globals.user.name} = {
        systemd.user.timers.aha-fr-report = {
          Unit.Description = "aha-fr-report timer";
          Timer = {
            Persistent = true;
            OnCalendar = cfg.schedule.onCalendar;
          };
          Install.WantedBy = [ "timers.target" ];
        };

        systemd.user.services.aha-fr-report = {
          Unit = {
            Description = "Refresh per-customer Aha! FR reports (Sheet + PDF)";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Service.Type = "oneshot";
          Service.ExecStart = "${aha-fr-report}/bin/aha-fr-report";
        };
      };
    })
  ];
}
