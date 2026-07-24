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

  # The whole package directory (vendor/, scripts/, assets/) copied into one Nix
  # store path as-is, so the scripts' own relative-path resolution
  # ($(dirname "$0")-style, matching the aha skill's own scripts) keeps working
  # unchanged rather than needing per-file substituteInPlace.
  #
  # customers.txt is deliberately not among them. It names customers, their Aha!
  # organization ids and their Drive folder ids, and this flake is a public
  # repository whose contents also land in the world-readable /nix/store. Only
  # customers.txt.example ships; the live list is read at runtime from
  # cfg.customersFile, the same off-store treatment secretsFile gets.
  src = pkgs.runCommand "aha-fr-report-src" { } ''
    mkdir -p "$out"
    cp -r ${./vendor} "$out/vendor"
    cp -r ${./scripts} "$out/scripts"
    cp -r ${./assets} "$out/assets"
    cp ${./customers.txt.example} "$out/customers.txt.example"
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
    export AHA_FR_CUSTOMERS_FILE="${cfg.customersFile}"
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

    customersFile = lib.mkOption {
      type = lib.types.str;
      default = "${globals.user.homeDirectory}/.config/aha-fr-report/customers.txt";
      description = ''
        Path to the live customer list, read at runtime. Kept off-store and out
        of this repository for the same reason as secretsFile: it names
        customers, their Aha! organization ids and their Drive folder ids, and
        both a public flake and /nix/store are world-readable. See
        modules/apps/cli/aha-fr-report/customers.txt.example for the format and
        the one-time setup.
      '';
    };

    schedule = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Run aha-fr-report (all customers.txt entries) on a systemd user
          timer. The primary user lingers, so the timer fires from boot and
          does not need anyone to log in. Requires home-manager and a
          completed `gws auth login` on the host.
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
      # A user timer, not a system one, so the report runs as the user whose
      # gws credentials it uses. The primary user lingers (see
      # modules/system/linger), so the user manager is up from boot and this
      # fires on schedule whether or not anyone has logged in. Persistent
      # means a run missed while the machine was off happens at the next boot
      # rather than being skipped.
      #
      # Running with no session is safe here, which is worth recording because
      # it is not obvious. gws does not need the login keyring: its credential
      # store is ~/.config/gws/credentials.enc, decrypted with a key that the
      # `file` backend keeps in ~/.config/gws/.encryption_key. Checked by
      # pointing gws at a copy of the config with the token cache removed (so a
      # refresh was forced) and DBUS_SESSION_BUS_ADDRESS aimed at a dead
      # socket. The Drive call still succeeded, and deleting .encryption_key
      # from that copy is what turned it into "Decryption failed".
      #
      # The `file` backend is pinned on the gws binary itself rather than here,
      # so `gws auth login` and a scheduled run cannot end up on different
      # keys. See modules/apps/cli/gws/build for why that difference is
      # destructive rather than merely inconsistent.
      #
      # This does mean the timer cannot be bound to graphical-session.target.
      # Doing that would look like a safety measure and would instead stop the
      # report from ever running on a machine that reboots unattended.
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
          # Retry on failure, matching ballpoint-probe.service. Without a
          # session to wait for, the user manager starts early in the boot and
          # Persistent fires the catch-up run straight away, potentially before
          # DHCP and tailscale have settled. There is no network-online.target
          # in the user manager to order against. Persistent also stamps on
          # trigger rather than on success, so a first attempt that fails
          # against a dead network would consume the missed occurrence and the
          # report would silently not happen that day.
          #
          # The numbers are a window, so state it rather than leaving it to be
          # worked out: 10 starts at 3 minutes apart covers roughly 27 minutes
          # from the first attempt, well inside the 1h limit interval. A link
          # that takes longer than that to come up loses the day anyway, since
          # Persistent has already stamped the occurrence.
          #
          # Retrying the whole batch is only safe because the run is
          # idempotent. run-all.sh exits non-zero only when *nothing* succeeded
          # (a dead network or an expired login), never for a partial failure,
          # and each artifact is uploaded with drive-lib.sh's
          # upload_or_replace_file, which replaces a same-named file rather than
          # stacking a second copy beside it. Without both of those, a single
          # broken customer would re-run the batch on every attempt and litter
          # customer-facing folders with duplicates.
          Unit = {
            Description = "Refresh per-customer Aha! FR reports (Sheet + PDF)";
            StartLimitBurst = 10;
            StartLimitIntervalSec = "1h";
          };
          #
          # Exit 2 is run-all.sh's configuration error: no customer list, or a
          # list with no usable entries. Retrying that ten times changes
          # nothing, so it fails once and says why in the journal instead.
          Service = {
            Type = "oneshot";
            Restart = "on-failure";
            RestartPreventExitStatus = 2;
            RestartSec = "3min";
            ExecStart = "${aha-fr-report}/bin/aha-fr-report";
          };
        };
      };
    })
  ];
}
