{
  lib,
  pkgs,
  versions,
  ...
}:
pkgs.stdenv.mkDerivation {
  pname = "kotlin-lsp";
  version = versions.cli.kotlin-lsp.version;

  src = pkgs.fetchurl {
    url = "https://download-cdn.jetbrains.com/kotlin-lsp/${versions.cli.kotlin-lsp.version}/kotlin-lsp-${versions.cli.kotlin-lsp.version}-linux-x64.zip";
    inherit (versions.cli.kotlin-lsp) hash;
  };

  nativeBuildInputs = [
    pkgs.unzip
    pkgs.autoPatchelfHook
    pkgs.makeWrapper
  ];

  buildInputs = [
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
  ];

  # The bundled JRE includes GUI/audio libs (libawt_xawt, libwlsplashscreen,
  # libjsound) that need X11/Wayland/ALSA. Since we run headless
  # (-Djava.awt.headless=true), skip these optional deps rather than pulling
  # in the entire X11/audio stack.
  autoPatchelfIgnoreMissingDeps = [
    "libX11.so.6"
    "libXext.so.6"
    "libXrender.so.1"
    "libXtst.so.6"
    "libXi.so.6"
    "libfreetype.so.6"
    "libwayland-client.so.0"
    "libwayland-cursor.so.0"
    "libasound.so.2"
  ];

  dontBuild = true;

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/{lib/kotlin-lsp,bin}
    cp -r lib $out/lib/kotlin-lsp/
    cp -r jre $out/lib/kotlin-lsp/
    cp -r native $out/lib/kotlin-lsp/

    chmod +x $out/lib/kotlin-lsp/jre/bin/java

    makeWrapper "$out/lib/kotlin-lsp/jre/bin/java" "$out/bin/kotlin-lsp" \
      --add-flags "--add-opens java.base/java.io=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/java.lang=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/java.lang.ref=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/java.lang.reflect=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/java.net=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/java.nio=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/java.nio.charset=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/java.text=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/java.time=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/java.util=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/java.util.concurrent=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/java.util.concurrent.atomic=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/java.util.concurrent.locks=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/jdk.internal.ref=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/jdk.internal.vm=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/sun.net.dns=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/sun.nio.ch=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/sun.nio.fs=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/sun.security.ssl=ALL-UNNAMED" \
      --add-flags "--add-opens java.base/sun.security.util=ALL-UNNAMED" \
      --add-flags "--add-opens java.desktop/java.awt=ALL-UNNAMED" \
      --add-flags "--add-opens java.desktop/java.awt.event=ALL-UNNAMED" \
      --add-flags "--add-opens java.desktop/java.awt.font=ALL-UNNAMED" \
      --add-flags "--add-opens java.desktop/java.awt.image=ALL-UNNAMED" \
      --add-flags "--add-opens java.desktop/javax.swing=ALL-UNNAMED" \
      --add-flags "--add-opens java.desktop/javax.swing.plaf.basic=ALL-UNNAMED" \
      --add-flags "--add-opens java.desktop/javax.swing.text=ALL-UNNAMED" \
      --add-flags "--add-opens java.desktop/sun.font=ALL-UNNAMED" \
      --add-flags "--add-opens java.management/sun.management=ALL-UNNAMED" \
      --add-flags "--add-opens jdk.attach/sun.tools.attach=ALL-UNNAMED" \
      --add-flags "--add-opens jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED" \
      --add-flags "--add-opens jdk.internal.jvmstat/sun.jvmstat.monitor=ALL-UNNAMED" \
      --add-flags "--add-opens jdk.jdi/com.sun.tools.jdi=ALL-UNNAMED" \
      --add-flags "--enable-native-access=ALL-UNNAMED" \
      --add-flags "-Djdk.lang.Process.launchMechanism=FORK" \
      --add-flags "-Djava.awt.headless=true" \
      --add-flags "-Djava.system.class.loader=com.intellij.util.lang.PathClassLoader" \
      --add-flags "-Xlog:cds=off" \
      --add-flags "-cp '$out/lib/kotlin-lsp/lib/*'" \
      --add-flags "com.jetbrains.ls.kotlinLsp.KotlinLspServerKt"
  '';

  meta = with lib; {
    description = "JetBrains Kotlin Language Server - https://github.com/Kotlin/kotlin-lsp";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
  };
}
