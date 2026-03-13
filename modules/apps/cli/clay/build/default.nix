{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
  versions,
}:

buildNpmPackage rec {
  pname = "clay";
  inherit (versions.cli.clay) version npmDepsHash;

  src = fetchurl {
    url = "https://registry.npmjs.org/claude-relay/-/claude-relay-${version}.tgz";
    inherit (versions.cli.clay) hash;
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    ${lib.getExe jq} '.overrides = {"nodemailer": "^7.0.11"}' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  dontNpmBuild = true;

  meta = with lib; {
    description = "Web UI for Claude Code with remote access and push notifications";
    homepage = "https://github.com/chadbyte/clay";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "claude-relay";
  };
}
