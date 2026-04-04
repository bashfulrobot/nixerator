{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
  versions,
}:

buildNpmPackage rec {
  pname = "claudito";
  inherit (versions.cli.claudito) version npmDepsHash;

  npmDepsFetcherVersion = 2;

  src = fetchurl {
    url = "https://registry.npmjs.org/claudito/-/claudito-${version}.tgz";
    inherit (versions.cli.claudito) hash;
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;
  dontNpmInstall = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/node_modules/claudito"
    cp -r . "$out/lib/node_modules/claudito"

    mkdir -p "$out/bin"
    makeWrapper "${nodejs}/bin/node" "$out/bin/claudito" \
      --add-flags "$out/lib/node_modules/claudito/dist/cli.js" \
      --prefix PATH : "${nodejs}/bin"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Web-based dashboard for orchestrating multiple Claude Code agents";
    homepage = "https://github.com/comfortablynumb/claudito";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "claudito";
  };
}
