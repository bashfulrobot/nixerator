# Local package for the Claude desktop app (Electron).
#
# nixpkgs has no claude-desktop derivation. Anthropic distributes it only as a
# Debian .deb (https://code.claude.com/docs/en/desktop-linux) containing a
# self-contained, bundled Electron 42 runtime under /usr/lib/claude-desktop
# (its own libEGL/libGLESv2/libffmpeg/libvulkan, chrome-sandbox, native
# node modules: @ant/claude-native + node-pty). So we unpack the .deb and
# patchelf the bundled binaries in place, following nixpkgs' `slack`
# derivation (which packages Slack's .deb the same way).
#
# The bundled Electron keeps us on the exact runtime Anthropic ships (rather
# than swapping in nixpkgs' electron and risking behavioural drift with the
# Cowork/Code helpers). The chrome-sandbox binary loses its setuid bit in the
# store, so Chromium falls back to the unprivileged user-namespace sandbox
# (enabled by default on NixOS) -- the same posture as slack/vscode/etc.
#
# Version + hash pinned in settings/versions.nix (gui.claude-desktop); the .deb
# URL is derived from aptRepo + package + version there.

{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  makeWrapper,

  # Electron/Chromium runtime libraries. This is nixpkgs `slack`'s dependency
  # set (same Electron family) plus libsecret, which claude-desktop's Depends
  # lists (libsecret-1-0) for credential storage via Electron safeStorage.
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  curl,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libGL,
  libappindicator-gtk3,
  libdrm,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  libxcb,
  libxkbcommon,
  libgbm,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  wayland,
  xdg-utils,
  libxtst,
  libxscrnsaver,
  libxrender,
  libxrandr,
  libxi,
  libxfixes,
  libxext,
  libxdamage,
  libxcursor,
  libxcomposite,
  libx11,
  libxshmfence,
  libxkbfile,

  versions,
}:

let
  pname = "claude-desktop";
  v = versions.gui.claude-desktop;
  inherit (v) version package aptRepo;

  # Debian pool layout: pool/main/<first-letter>/<package>/<package>_<ver>_<arch>.deb
  src = fetchurl {
    url = "${aptRepo}/pool/main/${lib.substring 0 1 package}/${package}/${package}_${version}_amd64.deb";
    inherit (v) hash;
  };

  rpath =
    lib.makeLibraryPath [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      curl
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      libGL
      libappindicator-gtk3
      libdrm
      libnotify
      libpulseaudio
      libsecret
      libuuid
      libxcb
      libxkbcommon
      libgbm
      nspr
      nss
      pango
      pipewire
      stdenv.cc.cc
      systemd
      wayland
      libx11
      libxscrnsaver
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxtst
      libxkbfile
      libxshmfence
    ]
    + ":${lib.getLib stdenv.cc.cc}/lib64";
in
stdenv.mkDerivation {
  inherit pname version src;

  buildInputs = [
    gtk3 # needed for GSETTINGS_SCHEMAS_PATH
  ];

  nativeBuildInputs = [
    dpkg
    makeWrapper
  ];

  dontUnpack = true;
  dontBuild = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    # The .deb contains a setuid binary (chrome-sandbox), so 'dpkg -x' bails --
    # extract the data tarball directly (matches nixpkgs slack).
    dpkg --fsys-tarfile $src | tar --extract
    rm -rf usr/share/lintian usr/share/doc

    mkdir -p $out
    mv usr/* $out

    # Otherwise the store paths look "suspicious" (world/group-writable bits).
    chmod -R g-w $out

    # Patch every ELF executable, shared object and native node module to use
    # the Nix loader + rpath. Appending $out/lib/claude-desktop lets the bundled
    # libEGL/libGLESv2/libffmpeg/libvulkan resolve. `|| true` mirrors slack:
    # some payload files (data blobs, non-ELF .node stubs) aren't patchable.
    for file in $(find $out -type f \( -perm /0111 -o -name '*.so*' -o -name '*.node' \)); do
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" 2>/dev/null || true
      patchelf --set-rpath "${rpath}:$out/lib/claude-desktop" "$file" 2>/dev/null || true
    done

    # Replace the bin/claude-desktop symlink (-> ../lib/claude-desktop/...) with
    # a startup wrapper. GSETTINGS_SCHEMAS_PATH comes from the gtk3 buildInput;
    # xdg-utils on PATH lets the app open claude:// and external links. The
    # ozone flags enable native Wayland only when the session opts in via
    # NIXOS_OZONE_WL (matches how slack/brave-origin are wrapped in this repo).
    #
    # --password-store=gnome-libsecret forces Electron's safeStorage onto the
    # libsecret/Secret Service backend (gnome-keyring here). Without it, Electron
    # auto-detects the backend from XDG_CURRENT_DESKTOP, which is "Hyprland" on
    # this compositor -- not GNOME/KDE -- so it falls back to plaintext and warns
    # that sign-in "won't be saved on this device." The workstations run
    # gnome-keyring (org.freedesktop.secrets), so pinning the backend makes the
    # keyring persist the session.
    rm $out/bin/claude-desktop
    makeWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop \
      --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH" \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --add-flags "--password-store=gnome-libsecret" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    # Point the .desktop entries at the wrapped binary (upstream uses a bare
    # `claude-desktop` that only resolves via PATH). The main Exec plus both
    # NewChat/NewCode actions share the same prefix, so a global sed is correct.
    sed -i "s|Exec=claude-desktop|Exec=$out/bin/claude-desktop|g" \
      $out/share/applications/com.anthropic.Claude.desktop

    runHook postInstall
  '';

  meta = {
    homepage = "https://www.anthropic.com/claude-code";
    description = "Claude desktop app (Chat, Cowork, and Claude Code) for Linux";
    longDescription = ''
      Anthropic's Claude desktop application repackaged from the official
      Debian .deb. Provides the Chat, Cowork, and Claude Code tabs with
      parallel sessions, visual diff review, an integrated terminal/editor and
      live app preview. Linux support is in beta.
    '';
    changelog = "https://code.claude.com/docs/en/desktop-linux";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "claude-desktop";
    maintainers = [ ];
  };
}
