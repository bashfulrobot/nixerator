{
  lib,
  pkgs,
  versions,
  ...
}:
pkgs.buildGoModule {
  pname = "yaml-schema-router";
  inherit (versions.cli.yaml-schema-router) version vendorHash;

  src = pkgs.fetchFromGitHub {
    owner = "tepea-code";
    repo = "yaml-schema-router";
    rev = "v${versions.cli.yaml-schema-router.version}";
    inherit (versions.cli.yaml-schema-router) hash;
  };

  subPackages = [ "cmd/yaml-schema-router" ];

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Content-based JSON schema routing proxy for yaml-language-server";
    homepage = "https://github.com/tepea-code/yaml-schema-router";
    license = licenses.mit;
    mainProgram = "yaml-schema-router";
    maintainers = [ ];
    platforms = platforms.unix;
    sourceProvenance = with sourceTypes; [ fromSource ];
  };
}
