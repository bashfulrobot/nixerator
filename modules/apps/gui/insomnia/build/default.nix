# Local override for Insomnia API client (ahead of nixpkgs)
# Version managed in settings/versions.nix
#
# Parameterized so the same fetch/meta/darwin logic builds both the pinned
# stable package and the side-by-side v13 beta:
#   versionKey  - key under versions.gui (which entry to fetch)
#   pname       - package + binary name (must be unique to avoid profile clashes)
#   desktopName - overrides the desktop "Name=" field (null = keep upstream)
#   configDir   - when set, isolate Electron's data dir under
#                 ~/.config/<configDir> and rename desktop/icon assets to
#                 ${pname}.* (used by the beta so it cannot migrate stable's DB)

{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  undmg,
  makeWrapper,
  runCommand,
  versions,
  versionKey ? "insomnia",
  pname ? "insomnia",
  desktopName ? null,
  configDir ? null,
}:
let
  v = versions.gui.${versionKey};
  inherit (v) version;

  src =
    fetchurl
      {
        aarch64-darwin = {
          url = "https://github.com/Kong/insomnia/releases/download/core%40${version}/Insomnia.Core-${version}.dmg";
          hash = v.platformHashes.aarch64-darwin;
        };
        x86_64-darwin = {
          url = "https://github.com/Kong/insomnia/releases/download/core%40${version}/Insomnia.Core-${version}.dmg";
          hash = v.platformHashes.x86_64-darwin;
        };
        x86_64-linux = {
          url = "https://github.com/Kong/insomnia/releases/download/core%40${version}/Insomnia.Core-${version}.AppImage";
          hash = v.platformHashes.x86_64-linux;
        };
      }
      .${stdenv.system} or (throw "Unsupported system: ${stdenv.system}");

  meta = {
    homepage = "https://insomnia.rest";
    description = "Open-source, cross-platform API client for GraphQL, REST, WebSockets, SSE and gRPC, with Cloud, Local and Git storage";
    mainProgram = pname;
    changelog = "https://github.com/Kong/insomnia/releases/tag/core@${version}";
    license = lib.licenses.asl20;
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
      "x86_64-darwin"
    ];
    maintainers = with lib.maintainers; [
      markus1189
      kashw2
      DataHearth
    ];
  };
in
if stdenv.hostPlatform.isDarwin then
  stdenv.mkDerivation {
    inherit
      pname
      version
      src
      meta
      ;
    sourceRoot = ".";

    nativeBuildInputs = [ undmg ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications"
      mv Insomnia.app $out/Applications/
      runHook postInstall
    '';
  }
else
  let
    appimageContents = appimageTools.extract {
      inherit pname version src;
    };
  in
  if configDir == null then
    appimageTools.wrapType2 {
      inherit
        pname
        version
        src
        meta
        ;

      extraInstallCommands = ''
        # Install XDG Desktop file and its icon
        install -Dm444 ${appimageContents}/insomnia.desktop -t $out/share/applications
        install -Dm444 ${appimageContents}/insomnia.png -t $out/share/pixmaps
        # Preserve the %U field code so xdg-open passes the auth callback URL
        # (insomnia://...) into argv; without it the URL is dropped and cloud
        # login never completes.
        substituteInPlace $out/share/applications/insomnia.desktop \
            --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=insomnia %U'
      '';
    }
  else
    # Beta: wrap the launcher to isolate Electron's data dir, and install
    # renamed desktop/icon assets so the package can coexist with stable in the
    # systemPackages profile. The insomnia:// scheme handler is kept; because
    # the data dir is isolated, a beta-initiated login lands in the beta's data
    # dir whenever beta is the active default handler.
    let
      base = appimageTools.wrapType2 {
        inherit
          pname
          version
          src
          meta
          ;
      };
    in
    runCommand "${pname}-${version}"
      {
        inherit meta;
        nativeBuildInputs = [ makeWrapper ];
      }
      ''
        makeWrapper ${base}/bin/${pname} $out/bin/${pname} \
            --run 'export XDG_CONFIG_HOME="$HOME/.config/${configDir}"'

        install -Dm444 ${appimageContents}/insomnia.desktop $out/share/applications/${pname}.desktop
        install -Dm444 ${appimageContents}/insomnia.png $out/share/pixmaps/${pname}.png
        # Exec keeps %U for the insomnia:// auth callback; Icon/Name renamed so
        # the launcher entry is distinct from stable.
        substituteInPlace $out/share/applications/${pname}.desktop \
            --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=${pname} %U' \
            --replace-fail 'Icon=insomnia' 'Icon=${pname}' \
            --replace-fail 'Name=Insomnia' 'Name=${desktopName}'
      ''
