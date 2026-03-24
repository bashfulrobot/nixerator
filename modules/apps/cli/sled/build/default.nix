{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
  versions,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "sled";
  inherit (versions.cli.sled) version;

  src = fetchFromGitHub {
    owner = "layercodedev";
    repo = "sled";
    inherit (versions.cli.sled) rev hash;
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = versions.cli.sled.pnpmDepsHash;
    fetcherVersion = 3;
  };

  nativeBuildInputs = [
    nodejs
    pnpm_10
    pnpmConfigHook
    makeWrapper
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/sled"
    cp -r . "$out/lib/sled"

    mkdir -p "$out/bin"
    makeWrapper "${nodejs}/bin/node" "$out/bin/sled-server" \
      --prefix PATH : "${
        lib.makeBinPath [
          nodejs
          pnpm_10
        ]
      }" \
      --add-flags "$out/lib/sled/node_modules/.bin/wrangler" \
      --add-flags "dev" \
      --chdir "$out/lib/sled/app"

    makeWrapper "${pnpm_10}/bin/pnpm" "$out/bin/sled-migrate" \
      --chdir "$out/lib/sled" \
      --add-flags "migrate"

    runHook postInstall
  '';

  meta = {
    description = "Voice-controlled web UI for coding agents";
    homepage = "https://github.com/layercodedev/sled";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "sled-server";
  };
})
