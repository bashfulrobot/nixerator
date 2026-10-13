{
  lib,
  pkgs,
  versions,
  ...
}:
pkgs.stdenv.mkDerivation {
  pname = "kotlin-lsp";
  inherit (versions.cli.kotlin-lsp) version;

  # Upstream's "Standalone Kotlin LSP Archive". The old
  # download-cdn.jetbrains.com/kotlin-lsp/<v>/kotlin-lsp-<v>-linux-x64.zip
  # path was retired and now 404s for every version, including the one this
  # repo used to pin. See the note in settings/versions.nix.
  src = pkgs.fetchurl {
    url = "https://download.jetbrains.com/language-server/kotlin-server/${versions.cli.kotlin-lsp.version}/kotlin-server-${versions.cli.kotlin-lsp.version}.tar.gz";
    inherit (versions.cli.kotlin-lsp) hash;
  };

  nativeBuildInputs = [
    pkgs.autoPatchelfHook
    pkgs.makeWrapper
  ];

  buildInputs = [
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
  ];

  # The bundled JBR includes GUI/audio libs (libawt_xawt, libwlsplashscreen,
  # libjsound) that need X11/Wayland/ALSA. Since we run headless, skip these
  # optional deps rather than pulling in the entire X11/audio stack.
  autoPatchelfIgnoreMissingDeps = [
    "libX11.so.6"
    "libXext.so.6"
    "libXrender.so.1"
    "libXtst.so.6"
    "libXi.so.6"
    "libfreetype.so.6"
    "libwayland-client.so.0"
    "libwayland-cursor.so.0"
    "libxkbcommon.so.0"
    "libasound.so.2"
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/kotlin-lsp $out/bin
    cp -r . $out/lib/kotlin-lsp/

    chmod +x $out/lib/kotlin-lsp/bin/intellij-server
    chmod +x $out/lib/kotlin-lsp/jbr/bin/*

    # bin/intellij-server is the native launcher upstream now ships; it reads
    # product-info.json for the bundled JBR, the boot classpath and the main
    # class, so the long hand-written `java --add-opens ... -cp` command line
    # the old zip needed is gone. The deprecated kotlin-lsp.sh wrapper just
    # execs this binary.
    #
    # --stdio is mandatory: without it the launcher defaults to TCP server
    # mode on 127.0.0.1:9999, and helix/opencode/zed all speak LSP over the
    # process's stdin/stdout. The old entrypoint was stdio-only, so this flag
    # is what keeps the editor configs working unchanged.
    #
    # --system-path pins the caches/indexes directory. Unset, the launcher
    # picks a fresh /tmp/idea-system<random> per run and re-indexes the
    # project on every editor start.
    makeWrapper "$out/lib/kotlin-lsp/bin/intellij-server" "$out/bin/kotlin-lsp" \
      --add-flags "--stdio" \
      --add-flags "--system-path=\"\''${XDG_CACHE_HOME:-\$HOME/.cache}/kotlin-lsp\""

    runHook postInstall
  '';

  meta = with lib; {
    description = "JetBrains Kotlin Language Server - https://github.com/Kotlin/kotlin-lsp";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "kotlin-lsp";
  };
}
