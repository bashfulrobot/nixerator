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
# (`pnpm install --frozen-lockfile` + `pnpm run build`), plus the changes
# upstream's setup wizard makes to a fresh checkout for the two skills srv
# uses: /add-onecli (credential gateway) and /add-slack (channel).
#
# Each skill is a few nc: directives, reproduced here so the build stays pure:
#   nc:copy   -- files into src/, container/skills/, docs/ (postPatch below).
#                OneCLI's come from its in-tree payload; Slack's from
#                upstream's `channels` branch at a pinned rev (channelsSrc).
#   nc:append -- `import './onecli.js';` to src/gateway-providers/installed.ts
#                and `import './slack.js';` + `import './slack-a2a-guard.js';`
#                to src/channels/index.ts
#   nc:dep    -- @onecli-sh/sdk@2.2.1 and @chat-adapter/slack@4.29.0 into
#                package.json + pnpm-lock.yaml
# The appends and deps live in skills.patch, generated with pnpm 10.34.5
# against the pinned rev (`pnpm add <pkg>@<pin> --ignore-scripts`). Because
# that patch touches the lockfile, a rev bump is never just a rev bump: rebase
# the patch, then refresh `hash` and `pnpmDepsHash`. That is why the entry is
# updatePolicy = "manual" in settings/versions.nix. OneCLI's nc:run setup.ts
# is the curl-pipe installer, which server.nanoclaw replaces with declarative
# containers, so it is intentionally not reproduced. The Slack adapter is
# inert until SLACK_BOT_TOKEN is in .env, so carrying it costs nothing when
# server.nanoclaw.slack is off.
#
# The output is a read-only project tree. The module symlinks its code dirs
# into the writable WorkingDirectory, because NanoClaw derives every path
# (data/, groups/, store/, logs/, .env, container/agent-runner/src mounts) from
# process.cwd().
let
  pin = versions.server.nanoclaw;
  channelsPin = versions.server.nanoclaw-channels;
  # Upstream keeps channel adapters on a long-lived `channels` branch; the
  # /add-<channel> skills copy single files from it.
  channelsSrc = fetchFromGitHub {
    owner = "nanocoai";
    repo = "nanoclaw";
    inherit (channelsPin) rev hash;
  };
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
    tag = "${pin.tagPrefix}${pin.version}";
    inherit (pin) hash;
  };

  patches = [ ./skills.patch ];

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

  # nc:copy from both skills. Test files included, as the skills do, so `tsc`
  # compiles the same set of sources a setup-wizard install would.
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

    # .claude/skills/add-slack/SKILL.md, "Copy the channel payload".
    for f in \
      src/channels/slack.ts \
      src/channels/slack-lib.ts \
      src/channels/slack-lib.test.ts \
      src/channels/slack-a2a-guard.ts \
      src/channels/slack-a2a-guard.test.ts \
      src/channels/slack-raw-text.ts \
      src/channels/slack-raw-text.test.ts \
      src/channels/slack-registration.test.ts \
      src/channels/slack-instances-registration.test.ts \
      src/provisioning/slack-app.ts \
      src/provisioning/slack-app.test.ts \
      container/skills/slack-formatting/SKILL.md; do
      install -Dm644 "${channelsSrc}/$f" "$f"
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
    description = "NanoClaw personal AI assistant host (OneCLI gateway + Slack channel skills applied)";
    homepage = "https://github.com/nanocoai/nanoclaw";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
