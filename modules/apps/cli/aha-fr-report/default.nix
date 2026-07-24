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
          # report would silently not happen that day. RestartSec is minutes
          # rather than seconds so the retries outlast a slow link coming up.
          Unit = {
            Description = "Refresh per-customer Aha! FR reports (Sheet + PDF)";
            StartLimitBurst = 5;
            StartLimitIntervalSec = "1h";
          };
          Service = {
            Type = "oneshot";
            Restart = "on-failure";
            RestartSec = "2min";
            ExecStart = "${aha-fr-report}/bin/aha-fr-report";
          };
        };
      };
    })
  ];
}
