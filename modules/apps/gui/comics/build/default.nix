{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versions,
}:

let
  v = versions.gui.comics-downloader;
in
buildGoModule rec {
  pname = "comics-downloader";
  inherit (v) version;

  src = fetchFromGitHub {
    owner = "Girbons";
    repo = "comics-downloader";
    rev = "v${version}";
    inherit (v) hash;
  };

  inherit (v) vendorHash;

  subPackages = [ "cmd/downloader" ];

  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Tool to download comics and manga from various sites";
    homepage = "https://github.com/Girbons/comics-downloader";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "comics-downloader";
  };
}
