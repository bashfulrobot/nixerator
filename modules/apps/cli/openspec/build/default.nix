{
  lib,
  buildNpmPackage,
  fetchurl,
  versions,
}:

buildNpmPackage rec {
  pname = "openspec";
  inherit (versions.cli.openspec) version npmDepsHash;

  src = fetchurl {
    url = "https://registry.npmjs.org/@fission-ai/openspec/-/openspec-${version}.tgz";
    inherit (versions.cli.openspec) hash;
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  meta = with lib; {
    description = "AI-native system for spec-driven development";
    homepage = "https://github.com/Fission-AI/OpenSpec";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "openspec";
  };
}
