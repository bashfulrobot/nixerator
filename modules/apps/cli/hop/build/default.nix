{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versions,
}:

let
  v = versions.cli.hop;
in
buildGoModule rec {
  pname = "hop";
  inherit (v) version;

  src = fetchFromGitHub {
    owner = "abhayarya1709";
    repo = "agent-hop";
    rev = "${v.tagPrefix}${version}";
    inherit (v) hash;
  };

  # Standard library only (go.mod has no require lines), so nothing to vendor.
  vendorHash = null;

  subPackages = [ "cmd/hop" ];

  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Unofficial CLI for switching between Claude Code accounts (profiles)";
    homepage = "https://github.com/abhayarya1709/agent-hop";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "hop";
  };
}
