# Local package for Brave Origin (nightly) — a standalone, minimalist build of
# Brave that drops the revenue/extra-feature surface (Leo AI, Wallet, Rewards,
# VPN, News, Talk, Tor, Playlists, telemetry) while keeping Shields.
#
# nixpkgs has no Brave Origin derivation, so we package the upstream Linux zip
# from GitHub releases. The recipe mirrors nixpkgs' `make-brave.nix`
# (manual patchelf + wrapGAppsHook), adapted for the zip's flat program-dir
# layout (the zip is the contents of what the .deb ships under
# /opt/brave.com/<channel>/, with no usr/share tree, no .desktop, and icons
# named product_logo_<size>_nightly.png).
#
# Version managed in settings/versions.nix (gui.brave-origin).

{
  lib,
  stdenv,
  fetchurl,
  buildPackages,
  unzip,
  makeDesktopItem,
  copyDesktopItems,

  # Runtime libraries — same set nixpkgs uses for `brave`; the binaries here are
  # the same Chromium family, so the dependency surface is identical.
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  adwaita-icon-theme,
  gsettings-desktop-schemas,
  gtk3,
  gtk4,
  qt6,
  libx11,
  libxscrnsaver,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libdrm,
  libkrb5,
  libuuid,
  libxkbcommon,
  libxshmfence,
  libgbm,
  nspr,
  nss,
  pango,
  pipewire,
  snappy,
  udev,
  wayland,
  xdg-utils,
  coreutils,
  libxcb,
  zlib,
  libGL,

  # Necessary for USB audio devices.
  pulseSupport ? stdenv.hostPlatform.isLinux,
  libpulseaudio,

  # For video acceleration via VA-API.
  libvaSupport ? stdenv.hostPlatform.isLinux,
  libva,

  # Command line arguments which are always passed to the browser.
  commandLineArgs ? "",

  versions,
}:

let
  inherit (lib)
    optional
    makeLibraryPath
    makeSearchPathOutput
    makeBinPath
    strings
    escapeShellArg
    ;

  pname = "brave-origin-nightly";
  v = versions.gui.brave-origin;
  inherit (v) version;

  deps = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    gtk4
    libdrm
    libx11
    libGL
    libxkbcommon
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxshmfence
    libxtst
    libuuid
    libgbm
    nspr
    nss
    pango
    pipewire
    udev
    wayland
    libxcb
    zlib
    snappy
    libkrb5
    qt6.qtbase
  ]
  ++ optional pulseSupport libpulseaudio
  ++ optional libvaSupport libva;

  rpath = makeLibraryPath deps + ":" + makeSearchPathOutput "lib" "lib64" deps;
  binpath = makeBinPath deps;

  # Wayland is driven by NIXOS_OZONE_WL on NixOS (the gApps wrapper appends
  # --ozone-platform-hint=auto when it is set); WaylandWindowDecorations keeps
  # client-side decorations under wlroots compositors.
  enableFeatures = [ "AcceleratedVideoDecodeLinuxGL" ];

  iconSizes = [
    "16"
    "24"
    "32"
    "48"
    "64"
    "128"
    "256"
  ];

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "Brave Origin (Nightly)";
    genericName = "Web Browser";
    exec = "${pname} %U";
    icon = pname;
    # Best-effort WM_CLASS. Verify with `lswt` after the first rebuild and
    # correct this if Chromium reports a different class (brave nightly reports
    # "brave-browser-nightly"; the Origin flavour is expected to differ).
    startupWMClass = pname;
    categories = [
      "Network"
      "WebBrowser"
    ];
    mimeTypes = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
  };
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-origin-nightly-${version}-linux-amd64.zip";
    inherit (v) hash;
  };

  dontConfigure = true;
  dontBuild = true;
  # We patch the ELF interpreter/rpath manually below (matching nixpkgs brave),
  # so the generic patchelf fixup must not interfere.
  dontPatchELF = true;
  doInstallCheck = true;

  nativeBuildInputs = [
    unzip
    copyDesktopItems
    # override doesn't preserve splicing: must use `makeShellWrapper` from
    # `buildPackages` (see NixOS/nixpkgs#132651).
    (buildPackages.wrapGAppsHook3.override { makeWrapper = buildPackages.makeShellWrapper; })
  ];

  buildInputs = [
    # needed for GSETTINGS_SCHEMAS_PATH
    glib
    gsettings-desktop-schemas
    gtk3
    gtk4
    # needed for XDG_ICON_DIRS
    adwaita-icon-theme
  ];

  desktopItems = [ desktopItem ];

  # The zip has no single root directory; unpack into a known dir.
  unpackPhase = ''
    runHook preUnpack
    mkdir -p source
    unzip -q "$src" -d source
    runHook postUnpack
  '';

  sourceRoot = "source";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/opt/${pname}
    cp -R . $out/opt/${pname}

    export BINARYWRAPPER=$out/opt/${pname}/${pname}

    # Fix the bash path in the launcher and stop it from setting CHROME_WRAPPER
    # itself (the gApps wrapper sets it; double-setting trips the re-exec guard).
    substituteInPlace $BINARYWRAPPER \
        --replace-fail /bin/bash ${stdenv.shell} \
        --replace-fail 'CHROME_WRAPPER' 'WRAPPER'

    ln -sf $BINARYWRAPPER $out/bin/${pname}

    for exe in $out/opt/${pname}/{brave,chrome_crashpad_handler}; do
        patchelf \
            --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
            --set-rpath "${rpath}" $exe
    done

    # Replace xdg-settings and xdg-mime with the store versions.
    ln -sf ${xdg-utils}/bin/xdg-settings $out/opt/${pname}/xdg-settings
    ln -sf ${xdg-utils}/bin/xdg-mime $out/opt/${pname}/xdg-mime

    # Icons (upstream ships them as product_logo_<size>_nightly.png).
    for icon in ${strings.concatStringsSep " " iconSizes}; do
        mkdir -p $out/share/icons/hicolor/$icon\x$icon/apps
        ln -s $out/opt/${pname}/product_logo_''${icon}_nightly.png \
            $out/share/icons/hicolor/$icon\x$icon/apps/${pname}.png
    done

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${rpath}
      --prefix PATH : ${binpath}
      --suffix PATH : ${
        lib.makeBinPath [
          xdg-utils
          coreutils
        ]
      }
      --set CHROME_WRAPPER ${pname}
      --add-flags "--enable-features=${strings.concatStringsSep "," enableFeatures}\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+,WaylandWindowDecorations --enable-wayland-ime=true}}"
      --add-flags "--disable-features=OutdatedBuildDetector"
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
      --add-flags ${escapeShellArg commandLineArgs}
    )
  '';

  installCheckPhase = ''
    # Bypass the launcher (which swallows errors) and call the binary directly.
    $out/opt/${pname}/brave --version
  '';

  meta = {
    homepage = "https://brave.com/origin/";
    description = "Minimalist, standalone build of Brave with Leo/Wallet/Rewards/VPN/News stripped, Shields kept (nightly channel)";
    longDescription = ''
      Brave Origin is a pared-down Brave that removes the revenue and
      extra-feature surface (Leo AI, Wallet, Rewards, VPN, Brave News, Talk,
      Tor windows, Playlists, Speedreader and telemetry) while keeping the
      Shields ad-blocking and privacy protections. It is a separate
      distribution channel (brave-origin-nightly) from regular Brave and is
      free on Linux. Only the nightly channel currently ships Linux artifacts.
    '';
    changelog = "https://github.com/brave/brave-browser/releases/tag/v${version}";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.mpl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
    maintainers = [ ];
  };
}
