{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs_24,
  makeWrapper,
  fetchNpmDeps,
}:
let
  pname = "yepanywhere";
  version = "0.3.2";
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://registry.npmjs.org/yepanywhere/-/yepanywhere-${version}.tgz";
    hash = "sha256-ntjM9HaAHDFrP+Oy9nlnJ4895NmSHNKHvVYC+fzMayI=";
  };

  nativeBuildInputs = [
    nodejs_24
    makeWrapper
  ];

  npmDeps = fetchNpmDeps {
    src = ./.;
    hash = "sha256-8YVUll1WEuQSgjnf8HWtkqQxAohXtUjBDuSTUyJdsqI=";
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
    cp -r dist client-dist bundled package.json node_modules README.md "$out/libexec/${pname}/"
    makeWrapper ${nodejs_24}/bin/node "$out/bin/yepanywhere" \
      --add-flags "$out/libexec/${pname}/dist/cli.js"
  '';

  meta = with lib; {
    description = "Mobile-first supervisor for Claude Code agents";
    homepage = "https://github.com/kzahel/yepanywhere";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = pname;
  };
}

