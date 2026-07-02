{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versions,
}:

let
  v = versions.cli."iso-topology";
in
buildGoModule rec {
  pname = "iso-topology";
  inherit (v) version;

  src = fetchFromGitHub {
    owner = "bashfulrobot"; # fork of MarkovWangRR/iso-topology; audited at v0.15.0
    repo = "iso-topology";
    rev = "v${version}";
    inherit (v) hash;
  };

  inherit (v) vendorHash;

  env.CGO_ENABLED = "0";

  subPackages = [
    "cmd/isotopo"
    "cmd/isotopo-mcp"
  ];

  ldflags = [
    "-s"
    "-w"
  ];

  doCheck = false; # d2 rendering dependency fetches fonts/assets; tests fail in sandbox

  meta = with lib; {
    description = "Isometric 2.5D architecture diagrams from a text DSL, with an MCP server for agent use";
    homepage = "https://github.com/bashfulrobot/iso-topology";
    license = licenses.asl20;
    mainProgram = "isotopo";
  };
}
