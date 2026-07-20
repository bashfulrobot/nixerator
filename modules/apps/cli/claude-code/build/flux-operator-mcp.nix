{
  lib,
  pkgs,
  versions,
  ...
}:
let
  v = versions.cli.flux-operator-mcp;
in
pkgs.stdenv.mkDerivation {
  pname = "flux-operator-mcp";
  inherit (v) version;

  # Prebuilt GoReleaser binary from the flux-operator release, not nixpkgs.
  # Statically linked (CGO disabled), so it runs on NixOS without patchelf,
  # same as the kubernetes-mcp-server and cpx binaries in this repo.
  src = pkgs.fetchurl {
    url = "https://github.com/${v.repo}/releases/download/${v.tagPrefix}${v.version}/flux-operator-mcp_${v.version}_linux_amd64.tar.gz";
    inherit (v) hash;
  };

  dontBuild = true;
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 flux-operator-mcp $out/bin/flux-operator-mcp
  '';

  meta = with lib; {
    description = "Flux Operator MCP server: read-only AI-agent access to Flux CD over the Model Context Protocol - https://github.com/controlplaneio-fluxcd/flux-operator";
    homepage = "https://fluxcd.control-plane.io/mcp/";
    license = licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "flux-operator-mcp";
  };
}
