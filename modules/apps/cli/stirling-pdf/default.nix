{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.stirling-pdf;
  username = globals.user.name;
  pkg = pkgs.callPackage ./build { inherit versions; };

  # Launcher wrapper: start the app (if not running) and open the browser.
  # All native dependencies are available via runtimeInputs and are inherited
  # by the backgrounded java process, so Stirling PDF can call tesseract,
  # libreoffice, etc. as subprocesses.
  stirling-pdf-launcher = pkgs.writeShellApplication {
    name = "stirling-pdf";
    runtimeInputs = with pkgs; [
      jdk21 # Java runtime
      # OCR with broad language support (eng required; others common world langs)
      (tesseract4.override {
        enableLanguages = [
          "eng" # English — required, do not remove
          "fra" # French
          "deu" # German
          "spa" # Spanish
          "ita" # Italian
          "por" # Portuguese
          "rus" # Russian
          "chi_sim" # Chinese Simplified
          "chi_tra" # Chinese Traditional
          "jpn" # Japanese
          "kor" # Korean
          "ara" # Arabic
          "hin" # Hindi
          "nld" # Dutch
          "pol" # Polish
          "swe" # Swedish
        ];
      })
      libreoffice # Document format conversion
      poppler-utils # PDF utilities
      pngquant # PNG optimization
      jbig2enc # JBIG2 OCR compression
      ghostscript # PDF processing
      qpdf # PDF manipulation
      unpaper # Document image cleanup pre-OCR
      unoconv # LibreOffice UNO bridge
      calibre # eBook/HTML conversion
      python3Packages.weasyprint # HTML→PDF
      python3Packages.opencv-python-headless # Pattern recognition
      curl # Used for readiness check
      xdg-utils # For xdg-open
      coreutils # mkdir, etc.
    ];
    text = ''
      PORT="${toString cfg.port}"
      DATA_DIR="${cfg.dataDir}"
      JAR="${pkg}/share/stirling-pdf/Stirling-PDF.jar"

      # Ensure data directory structure exists
      mkdir -p "$DATA_DIR"/{configs,logs,pipeline,tessdata}

      # If already running on the port, just open the browser
      if curl -sf "http://localhost:''${PORT}" > /dev/null 2>&1; then
        xdg-open "http://localhost:''${PORT}"
        exit 0
      fi

      # Start Stirling PDF in the background from the data directory
      cd "$DATA_DIR"
      SERVER_PORT="''${PORT}" SERVER_HOST="127.0.0.1" \
        nohup java -jar "$JAR" > "$DATA_DIR/logs/stirling-pdf.log" 2>&1 &

      echo "Starting Stirling PDF..."

      # Wait up to 60s for the server to be ready
      for _i in $(seq 1 60); do
        if curl -sf "http://localhost:''${PORT}" > /dev/null 2>&1; then
          xdg-open "http://localhost:''${PORT}"
          echo "Stirling PDF started at http://localhost:''${PORT}"
          exit 0
        fi
        sleep 1
      done

      echo "Stirling PDF did not respond after 60s. Check logs at $DATA_DIR/logs/stirling-pdf.log"
      exit 1
    '';
  };
in
{
  options = {
    apps.cli.stirling-pdf = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Stirling PDF native installation (PDF toolkit web UI).";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port to serve Stirling PDF on.";
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/home/${username}/.local/share/stirling-pdf";
        description = "Working directory for configs, logs, pipeline, and tessdata.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ stirling-pdf-launcher ];

    # Desktop launcher — home.file pattern (syncthing/spotify convention in this repo)
    home-manager.users.${username} = {
      home.file = {
        "stirling-pdf.desktop" = {
          text = ''
            [Desktop Entry]
            Name=Stirling PDF
            GenericName=PDF Toolkit
            Comment=Launch Stirling PDF and open its web UI
            Exec=stirling-pdf
            Icon=${pkg}/share/stirling-pdf/stirling.svg
            Type=Application
            Categories=Office;
            Keywords=pdf;
            Terminal=false
          '';
          target = ".local/share/applications/stirling-pdf.desktop";
        };
      };
    };
  };
}
