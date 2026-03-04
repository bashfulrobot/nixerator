{
  lib,
  buildNpmPackage,
  fetchurl,
  python3,
  versions,
}:

buildNpmPackage rec {
  pname = "yepanywhere";
  inherit (versions.cli.yepanywhere) version npmDepsHash;

  src = fetchurl {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    inherit (versions.cli.yepanywhere) sha256;
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  nativeBuildInputs = [ python3 ];

  dontNpmBuild = true;

  meta = with lib; {
    description = "Mobile supervision for Claude Code and Codex agents";
    homepage = "https://yepanywhere.com/";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = pname;
  };
}
