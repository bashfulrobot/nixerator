{
  lib,
  buildNpmPackage,
  fetchurl,
  versions,
}:

buildNpmPackage rec {
  pname = "get-shit-done-cc";
  inherit (versions.cli.get-shit-done) version;
  npmDepsHash = "";
  forceEmptyCache = true;

  src = fetchurl {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    inherit (versions.cli.get-shit-done) sha256;
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  meta = with lib; {
    description = "Meta-prompting and context engineering system for AI-assisted development";
    homepage = "https://github.com/gsd-build/get-shit-done";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = pname;
  };
}
