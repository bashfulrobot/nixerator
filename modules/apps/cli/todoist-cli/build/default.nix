{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
  versions,
}:

buildNpmPackage rec {
  pname = "doist-todoist-cli";
  inherit (versions.cli.todoist-cli) version npmDepsHash;

  src = fetchurl {
    url = "https://registry.npmjs.org/@doist/todoist-cli/-/todoist-cli-${version}.tgz";
    inherit (versions.cli.todoist-cli) hash;
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    # Drop the postinstall skill-sync step; it tries to write to $HOME which
    # is not writable in the Nix build sandbox. Users run `td skill install`
    # manually if they want the agent skills.
    ${lib.getExe jq} 'del(.scripts.postinstall)' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  dontNpmBuild = true;

  meta = with lib; {
    description = "Official command-line interface for Todoist";
    homepage = "https://todoist.com/cli";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "td";
  };
}
