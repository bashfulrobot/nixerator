{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs_24,
  makeWrapper,
  fetchNpmDeps,
}:
let
  pname = "mcp-server-sequential-thinking";
  version = "2025.12.18";
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@modelcontextprotocol/server-sequential-thinking/-/server-sequential-thinking-${version}.tgz";
    hash = "sha256-WiHm+kc3IrjmIqm7vdcrxtvN30MPJqtZic0z3+XcdwM=";
  };

  nativeBuildInputs = [
    nodejs_24
    makeWrapper
  ];

  npmDeps = fetchNpmDeps {
    src = ./.;
    hash = "sha256-+iNn23SbnJrWXIHzE4HZiUEkq+k4xLaplEr8Hdz/qmU=";
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
    cp -r dist package.json node_modules README.md "$out/libexec/${pname}/"
    makeWrapper ${nodejs_24}/bin/node "$out/bin/${pname}" \
      --add-flags "$out/libexec/${pname}/dist/index.js"
  '';

  meta = with lib; {
    description = "MCP server for sequential thinking and problem solving";
    homepage = "https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = pname;
  };
}

