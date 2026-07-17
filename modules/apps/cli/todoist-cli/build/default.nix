{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
  nodejs_24,
  versions,
}:

# todoist-cli 3.0.0 declares engines { node >= 24, npm >= 11 }; nixpkgs' default
# buildNpmPackage node here is 22, so pin the toolchain explicitly (same pattern
# as apps/cli/skillfish). package-lock.json is vendored because the published npm
# tarball ships none, so it must be regenerated whenever `version` moves:
#   curl -sL https://registry.npmjs.org/@doist/todoist-cli/-/todoist-cli-<v>.tgz | tar xz
#   cd package && npm install --package-lock-only --ignore-scripts
# then copy the result here and refresh npmDepsHash. That is why this entry is
# updatePolicy = "manual" in settings/versions.nix.
(buildNpmPackage.override { nodejs = nodejs_24; }) rec {
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
