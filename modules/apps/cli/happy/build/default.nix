{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
  versions,
}:

buildNpmPackage rec {
  pname = "happy-coder";
  inherit (versions.cli.happy) version npmDepsHash;

  npmDepsFetcherVersion = 2;

  src = fetchurl {
    url = "https://registry.npmjs.org/happy-coder/-/happy-coder-${version}.tgz";
    inherit (versions.cli.happy) hash;
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

    mkdir -p "$out/lib/node_modules/happy-coder"
    cp -r . "$out/lib/node_modules/happy-coder"

    mkdir -p "$out/bin"
    makeWrapper "${nodejs}/bin/node" "$out/bin/happy" \
      --add-flags "$out/lib/node_modules/happy-coder/bin/happy.mjs" \
      --prefix PATH : "${nodejs}/bin"
    makeWrapper "${nodejs}/bin/node" "$out/bin/happy-mcp" \
      --add-flags "$out/lib/node_modules/happy-coder/bin/happy-mcp.mjs" \
      --prefix PATH : "${nodejs}/bin"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Claude Code on the go - mobile monitoring and control";
    homepage = "https://happy.engineering";
    license = licenses.unfree;
    platforms = platforms.linux;
    mainProgram = "happy";
  };
}
