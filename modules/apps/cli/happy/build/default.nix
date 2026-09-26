{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
  versions,
}:

# happy-coder ships no package-lock.json in its published tarball, so one is
# vendored here (regenerated the same way as apps/cli/skillfish and
# apps/cli/todoist-cli):
#   curl -sL https://registry.npmjs.org/happy-coder/-/happy-coder-<v>.tgz | tar xz
#   cd package && npm install --package-lock-only --ignore-scripts --legacy-peer-deps
# then copy the result here and refresh npmDepsHash. --legacy-peer-deps is
# required: @anthropic-ai/claude-agent-sdk@0.2.141 peer-depends on zod@^4,
# but happy-coder's own root dependency pins zod@3.25.76, so a plain
# `npm install` refuses to resolve (ERESOLVE). That is why this entry is
# updatePolicy = "manual" in settings/versions.nix.
buildNpmPackage rec {
  pname = "happy-coder";
  inherit (versions.cli.happy) version npmDepsHash;

  npmDepsFetcherVersion = 2;

  src = fetchurl {
    url = "https://registry.npmjs.org/happy-coder/-/happy-coder-${version}.tgz";
    inherit (versions.cli.happy) hash;
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;
  dontNpmInstall = true;

  nativeBuildInputs = [ makeWrapper ];

  # The prebuilt dist/*.mjs bundles (pkgroll/esbuild output) still `require`/
  # `import` their runtime deps from node_modules rather than inlining them,
  # so node_modules has to ship alongside dist/ -- this is not a bundle-free
  # single-file CLI like some npm packages.
  #
  # happy-coder's own postinstall (scripts/unpack-tools.cjs) unpacks the
  # ripgrep/difftastic binaries it bundles per-platform under tools/archives/
  # into tools/unpacked/ for the current OS+arch. It needs no network (the
  # archives are already in the tarball), so it is safe to run inside the
  # build sandbox; dontNpmInstall above means `npm ci` never fires it
  # automatically, so it is invoked by hand below.
  installPhase = ''
    runHook preInstall

    node scripts/unpack-tools.cjs

    mkdir -p "$out/lib/node_modules/happy-coder"
    cp -r . "$out/lib/node_modules/happy-coder"

    mkdir -p "$out/bin"
    makeWrapper "${nodejs}/bin/node" "$out/bin/happy" \
      --add-flags "--no-warnings --no-deprecation $out/lib/node_modules/happy-coder/dist/index.mjs" \
      --prefix PATH : "${nodejs}/bin"
    makeWrapper "${nodejs}/bin/node" "$out/bin/happy-mcp" \
      --add-flags "--no-warnings --no-deprecation $out/lib/node_modules/happy-coder/dist/codex/happyMcpStdioBridge.mjs" \
      --prefix PATH : "${nodejs}/bin"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Mobile and web client for Claude Code and Codex -- pair a phone/browser to a local coding-agent session";
    homepage = "https://happy.engineering";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "happy";
  };
}
