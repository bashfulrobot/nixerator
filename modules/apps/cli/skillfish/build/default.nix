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
  pname = "skillfish";
  inherit (versions.cli.skillfish) version npmDepsHash;

  npmDepsFetcherVersion = 2;

  src = fetchurl {
    url = "https://registry.npmjs.org/skillfish/-/skillfish-${version}.tgz";
    inherit (versions.cli.skillfish) hash;
  };

  sourceRoot = "package";

  # The upstream tarball ships devDependencies in package.json but no
  # package-lock.json. The committed lockfile was regenerated via
  # `npm install --package-lock-only --ignore-scripts` after stripping
  # devDependencies + scripts, so strip them here to keep package.json
  # and package-lock.json in sync for `npm ci`.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    ${lib.getExe nodejs_22} -e '
      const fs = require("fs");
      const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
      delete pkg.devDependencies;
      delete pkg.scripts;
      fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2));
    '
  '';

  dontNpmBuild = true;
  dontNpmInstall = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/node_modules/skillfish"
    cp -r . "$out/lib/node_modules/skillfish"

    mkdir -p "$out/bin"
    makeWrapper "${nodejs_22}/bin/node" "$out/bin/skillfish" \
      --add-flags "$out/lib/node_modules/skillfish/dist/index.js" \
      --prefix PATH : "${nodejs_22}/bin"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Skill manager for AI coding agents -- install, update, sync Skills across Claude Code, Cursor, Copilot, and more";
    homepage = "https://skill.fish";
    license = licenses.agpl3Only;
    platforms = platforms.linux;
    mainProgram = "skillfish";
  };
}
