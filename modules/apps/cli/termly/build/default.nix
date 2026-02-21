{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs_24,
  makeWrapper,
  fetchNpmDeps,
}:
let
  pname = "termly-cli";
  version = "1.9.0";
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@termly-dev/cli/-/cli-${version}.tgz";
    hash = "sha256-lQkgolx5ih2H3qs1l6y30bz2+Spnn6+yUMabioySFHI=";
  };

  nativeBuildInputs = [
    nodejs_24
    makeWrapper
  ];

  npmDeps = fetchNpmDeps {
    src = ./.;
    hash = "sha256-j+uZKkKSyIM8u500TExkfMBQxw6YsSXcGaSyXzdFsSg=";
  };

  unpackPhase = ''
    tar -xzf "$src" --strip-components=1
  '';

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  buildPhase = ''
    export HOME="$TMPDIR"
    npm ci --ignore-scripts --offline --cache "$npmDeps" --no-audit --no-fund
  '';

  installPhase = ''
    mkdir -p "$out/libexec/${pname}" "$out/bin"
    cp -r bin lib scripts package.json node_modules README.md "$out/libexec/${pname}/"
    makeWrapper ${nodejs_24}/bin/node "$out/bin/termly" \
      --add-flags "$out/libexec/${pname}/bin/cli.js"
  '';

  meta = with lib; {
    description = "Termly CLI for mirroring AI coding sessions to mobile";
    homepage = "https://github.com/termly-dev/termly-cli";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "termly";
  };
}

