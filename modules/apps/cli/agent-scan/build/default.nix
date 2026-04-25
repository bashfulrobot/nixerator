{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
  versions,
}:

let
  pname = "agent-scan";
  v = versions.cli.agent-scan;
  inherit (v) version;

  arch =
    {
      x86_64-linux = "linux-x86_64";
      aarch64-darwin = "macos-arm64";
      x86_64-darwin = "macos-x86_64";
    }
    .${stdenv.system} or (throw "agent-scan: unsupported system ${stdenv.system}");

  src = fetchurl {
    url = "https://github.com/snyk/agent-scan/releases/download/v${version}/agent-scan-${version}-${arch}";
    hash = v.platformHashes.${stdenv.system};
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  dontUnpack = true;

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib
    zlib
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/snyk-agent-scan
    runHook postInstall
  '';

  meta = {
    description = "Snyk security scanner for AI agent components (MCP servers, skills, tools)";
    homepage = "https://github.com/snyk/agent-scan";
    license = lib.licenses.asl20;
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    mainProgram = "snyk-agent-scan";
  };
}
