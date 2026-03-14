{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
  versions,
}:

buildNpmPackage rec {
  pname = "clay";
  inherit (versions.cli.clay) version npmDepsHash;

  npmDepsFetcherVersion = 2;

  src = fetchurl {
    url = "https://registry.npmjs.org/clay-server/-/clay-server-${version}.tgz";
    inherit (versions.cli.clay) hash;
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

    mkdir -p "$out/lib/node_modules/clay-server"
    cp -r . "$out/lib/node_modules/clay-server"

    mkdir -p "$out/bin"
    makeWrapper "${nodejs}/bin/node" "$out/bin/clay-server" \
      --add-flags "$out/lib/node_modules/clay-server/bin/cli.js"
    makeWrapper "${nodejs}/bin/node" "$out/bin/clay-dev" \
      --add-flags "$out/lib/node_modules/clay-server/bin/cli.js"
    makeWrapper "${nodejs}/bin/node" "$out/bin/claude-relay" \
      --add-flags "$out/lib/node_modules/clay-server/bin/claude-relay.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Web UI for Claude Code with remote access and push notifications";
    homepage = "https://github.com/chadbyte/clay";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "clay-server";
  };
}
