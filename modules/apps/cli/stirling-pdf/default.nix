{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.cli.stirling-pdf;
  username = globals.user.name;

  stirling-pdf = pkgs.writeShellScriptBin "stirling-pdf" ''
    set -euo pipefail

    CONTAINER_NAME="stirling-pdf"
    PORT="${toString cfg.port}"
    DATA_DIR="${cfg.dataDir}"

    if docker ps -q -f "name=^''${CONTAINER_NAME}$" | grep -q .; then
      docker stop "$CONTAINER_NAME" > /dev/null
      docker rm "$CONTAINER_NAME" > /dev/null
      echo "Stirling PDF stopped."
    else
      docker rm "$CONTAINER_NAME" 2>/dev/null || true
      mkdir -p "$DATA_DIR"/{configs,logs,pipeline,tessdata}
      docker run -d \
        --name "$CONTAINER_NAME" \
        -p "$PORT:8080" \
        -v "$DATA_DIR/configs:/configs" \
        -v "$DATA_DIR/logs:/logs" \
        -v "$DATA_DIR/pipeline:/pipeline" \
        -v "$DATA_DIR/tessdata:/usr/share/tessdata" \
        stirlingtools/stirling-pdf:latest > /dev/null
      echo "Stirling PDF started at http://localhost:$PORT"
      xdg-open "http://localhost:$PORT"
    fi
  '';
in
{
  options = {
    apps.cli.stirling-pdf = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Stirling PDF toggle command (Docker-based PDF toolkit).";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Host port to expose Stirling PDF on.";
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/home/${username}/.local/share/stirling-pdf";
        description = "Directory for Stirling PDF persistent data.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ stirling-pdf ];
  };
}
