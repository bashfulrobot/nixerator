{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  pname = "kubernetes-mcp-server";
  version = "0.0.57";
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://registry.npmjs.org/kubernetes-mcp-server-linux-amd64/-/kubernetes-mcp-server-linux-amd64-${version}.tgz";
    hash = "sha256-csF1HhRFqccBcu+jCkRSIhxNJhhO6jMBISL81RMlLBc=";
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

