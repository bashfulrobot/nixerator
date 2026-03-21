{
  lib,
  buildNpmPackage,
  fetchurl,
  versions,
}:

buildNpmPackage rec {
  pname = "reap";
  inherit (versions.cli.reap) version npmDepsHash;

  src = fetchurl {
    url = "https://registry.npmjs.org/@c-d-cc/reap/-/reap-${version}.tgz";
    inherit (versions.cli.reap) hash;
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  # postinstall tries to write to $HOME/.reap/commands/ — harmless in sandbox
  NODE_OPTIONS = "--no-warnings";

  meta = with lib; {
    description = "Recursive Evolutionary Autonomous Pipeline for AI-assisted development";
    homepage = "https://github.com/c-d-cc/reap";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = pname;
  };
}
