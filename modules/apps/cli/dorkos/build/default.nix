{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs_22,
  versions,
}:

let
  buildNpm = buildNpmPackage.override { nodejs = nodejs_22; };
in
buildNpm rec {
  pname = "dorkos";
  inherit (versions.cli.dorkos) version npmDepsHash;

  npmDepsFetcherVersion = 2;

  src = fetchurl {
    url = "https://registry.npmjs.org/dorkos/-/dorkos-${version}.tgz";
    inherit (versions.cli.dorkos) hash;
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    # The committed package-lock.json was regenerated without devDependencies
    # (via `npm install --package-lock-only --ignore-scripts` after stripping
    # devDependencies from package.json). The upstream tarball still ships the
    # full devDependencies block in package.json, which causes `npm ci` to try
    # to resolve packages like @dorkos/eslint-config that aren't in the lockfile
    # or the offline cache -- resulting in ENOTCACHED. Strip them here so
    # package.json and package-lock.json agree.
    ${lib.getExe nodejs_22} -e '
      const fs = require("fs");
      const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
      delete pkg.devDependencies;
      fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2));
    '
  '';

  dontNpmBuild = true;
  dontNpmInstall = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/node_modules/dorkos"
    cp -r . "$out/lib/node_modules/dorkos"

    mkdir -p "$out/bin"
    makeWrapper "${nodejs_22}/bin/node" "$out/bin/dorkos" \
      --add-flags "$out/lib/node_modules/dorkos/dist/bin/cli.js" \
      --prefix PATH : "${nodejs_22}/bin"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Operating system for autonomous AI agents - scheduling, messaging, and agent coordination";
    homepage = "https://dorkos.ai";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "dorkos";
  };
}
