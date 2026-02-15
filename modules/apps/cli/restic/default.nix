{ pkgs, config, lib, ... }:

let
  cfg = config.apps.cli.restic;
  lazyrestic = pkgs.callPackage ./build/lazyrestic.nix { };
  backrestUi = pkgs.writeShellScriptBin "backrest-ui" ''
    #!/usr/bin/env bash
    set -euo pipefail

    url="''${BACKREST_URL:-http://127.0.0.1:9898}"
    "${pkgs.backrest}/bin/backrest" &
    pid="$!"

    cleanup() {
      if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        wait "$pid" || true
      fi
    }

    trap cleanup EXIT INT TERM

    for _ in $(seq 1 40); do
      if "${pkgs.curl}/bin/curl" -fsS "$url" >/dev/null 2>&1; then
        break
      fi
      sleep 0.25
    done

    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$url" >/dev/null 2>&1 || true
    fi

    echo "Backrest running at $url (pid: $pid). Press Ctrl+C to stop."
    wait "$pid"
  '';

in
{
  options = {
    apps.cli.restic.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable restic backup tools including restic, backrest, autorestic, and lazyrestic TUI.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.restic
      pkgs.backrest
      pkgs.autorestic
      lazyrestic
      backrestUi
    ];
  };
}
