{
  lib,
  buildNpmPackage,
  fetchurl,
  versions,
}:

buildNpmPackage rec {
  pname = "termly-cli";
  inherit (versions.cli.termly) version npmDepsHash;

  src = fetchurl {
    url = "https://registry.npmjs.org/@termly-dev/cli/-/cli-${version}.tgz";
    inherit (versions.cli.termly) hash;
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  meta = with lib; {
    description = "Mirror AI coding sessions to mobile - control Claude, Aider, Copilot from your phone";
    homepage = "https://github.com/termly-dev/cli";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "termly";
  };
}
