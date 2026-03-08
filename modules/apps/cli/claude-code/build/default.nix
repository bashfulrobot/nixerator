{
  lib,
  stdenvNoCC,
  fetchurl,
  versions,
}:
let
  pname = "kubernetes-mcp-server";
  v = versions.cli.kubernetes-mcp-server;
  inherit (v) version;
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://registry.npmjs.org/kubernetes-mcp-server-linux-amd64/-/kubernetes-mcp-server-linux-amd64-${version}.tgz";
    inherit (v) hash;
  };

  unpackPhase = ''
    tar -xzf "$src"
  '';

  installPhase = ''
    mkdir -p "$out/bin"
    install -Dm755 package/bin/kubernetes-mcp-server-linux-amd64 "$out/bin/${pname}"
  '';

  meta = with lib; {
    description = "Model Context Protocol server for Kubernetes and OpenShift";
    homepage = "https://github.com/containers/kubernetes-mcp-server";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
