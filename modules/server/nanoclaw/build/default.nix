{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs_22,
  node-gyp,
  python3,
  srcOnly,
  versions,
}:

# NanoClaw host process, built from source with the repo's own steps
# (`pnpm install --frozen-lockfile` + `pnpm run build`), plus the one change
# upstream's setup wizard makes to a fresh checkout: the /add-onecli skill.
#
# That skill (.claude/skills/add-onecli/SKILL.md) is three nc: directives, all
# reproduced here so the build stays pure:
#   1. nc:copy   -- payload files into src/, container/skills/, docs/ (postPatch)
#   2. nc:append -- `import './onecli.js';` to src/gateway-providers/installed.ts
#   3. nc:dep    -- @onecli-sh/sdk@2.2.1 into package.json + pnpm-lock.yaml
# (2) and (3) live in onecli-gateway.patch, generated with pnpm 10.34.5 against
# the pinned rev (`pnpm add @onecli-sh/sdk@2.2.1 --ignore-scripts`). Because
# that patch touches the lockfile, a rev bump is never just a rev bump: rebase
# the patch, then refresh `hash` and `pnpmDepsHash`. That is why the entry is
# updatePolicy = "manual" in settings/versions.nix. Skill 4 (nc:run setup.ts)
# is the curl-pipe OneCLI installer, which server.nanoclaw replaces with
# declarative containers, so it is intentionally not reproduced.
#
# The output is a read-only project tree. The module symlinks its code dirs
# into the writable WorkingDirectory, because NanoClaw derives every path
# (data/, groups/, store/, logs/, .env, container/agent-runner/src mounts) from
# process.cwd().
let
  pin = versions.server.nanoclaw;
  nodejs = nodejs_22;
  pnpm = pnpm_10;
  nodeSources = srcOnly nodejs;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "nanoclaw";
  inherit (pin) version;

  src = fetchFromGitHub {
    owner = "nanocoai";
    repo = "nanoclaw";
    inherit (pin) rev hash;
  };

  patches = [ ./onecli-gateway.patch ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      patches
      ;
    inherit pnpm;
    fetcherVersion = 4;
    hash = pin.pnpmDepsHash;
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    node-gyp
    python3
  ];

  # nc:copy from the add-onecli skill. Test files included, as the skill does,
  # so `tsc` compiles the same set of sources a setup-wizard install would.
  postPatch = ''
    payload=.claude/skills/add-onecli/payload
    for f in \
      src/gateway-providers/onecli-files.ts \
      src/gateway-providers/onecli-files.test.ts \
      src/gateway-providers/onecli.ts \
      src/gateway-providers/onecli.test.ts \
      src/gateway-providers/onecli-install.test.ts \
      container/skills/onecli-gateway/SKILL.md \
      container/skills/onecli-gateway/instructions.md \
      docs/onecli-upgrades.md; do
      install -Dm644 "$payload/$f" "$f"
    done
  '';

  buildPhase = ''
    runHook preBuild

    # pnpm 10 blocks install scripts outside onlyBuiltDependencies, and the
    # config hook installs with --ignore-scripts anyway, so better-sqlite3's
    # native addon is compiled here against the exact node it will run on.
    pushd node_modules/better-sqlite3
    npm run build-release --offline "--nodedir=${nodeSources}"
    mv build/Release/better_sqlite3.node .
    rm -rf build deps src
    install -Dm755 better_sqlite3.node build/Release/better_sqlite3.node
    rm better_sqlite3.node
    popd

    pnpm run build

    runHook postBuild
  '';

  # devDependencies stay: `tsx` runs the operator scripts (scripts/chat.ts,
  # scripts/init-cli-agent.ts, src/cli/client.ts behind `ncl`) exactly the way
  # upstream's `pnpm run chat` / bin/ncl do.
  installPhase = ''
    runHook preInstall

    root=$out/share/nanoclaw
    mkdir -p "$root"
    cp -r \
      package.json pnpm-lock.yaml pnpm-workspace.yaml versions.json tsconfig.json \
      dist src scripts setup container templates bin config-examples docs \
      node_modules "$root"/
    # Skill payloads are read by setup/update tooling; keep them so the tree
    # matches a wizard install, but never the husky hooks.
    cp -r .claude "$root"/.claude

    runHook postInstall
  '';

  # container/ is COPY'd into the agent image (entrypoint.sh) and bind-mounted
  # into agent containers (agent-runner/src, skills/). A /nix/store shebang
  # means nothing inside a node:22-slim container, so leave every shebang as
  # upstream wrote it. The host never execs a script from this tree directly.
  dontPatchShebangs = true;

  # Runtime check that the native addon actually loads against this node.
  doInstallCheck = true;
  installCheckPhase = ''
    ${lib.getExe nodejs} -e "require('$out/share/nanoclaw/node_modules/better-sqlite3')(':memory:').close()"
  '';

  passthru = {
    inherit nodejs pnpm;
  };

  meta = {
    description = "NanoClaw personal AI assistant host (with the OneCLI gateway skill applied)";
    homepage = "https://github.com/nanocoai/nanoclaw";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
