{
  lib,
  pkgs,
  versions,
  ...
}:
pkgs.stdenv.mkDerivation {
  pname = "yaml-schema-router";
  inherit (versions.cli.yaml-schema-router) version;

  src = pkgs.fetchurl {
    url = "https://github.com/tepea-code/yaml-schema-router/releases/download/v${versions.cli.yaml-schema-router.version}/yaml-schema-router_${versions.cli.yaml-schema-router.version}_linux_x86_64.tar.gz";
    inherit (versions.cli.yaml-schema-router) hash;
  };

  nativeBuildInputs = [
    pkgs.autoPatchelfHook
  ];

  buildInputs = [
    pkgs.stdenv.cc.cc.lib
  ];

  sourceRoot = ".";

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 yaml-schema-router $out/bin/yaml-schema-router
    install -Dm644 LICENSE $out/share/doc/yaml-schema-router/LICENSE
    install -Dm644 README.md $out/share/doc/yaml-schema-router/README.md
    runHook postInstall
  '';

  meta = with lib; {
    description = "Content-based JSON schema routing proxy for yaml-language-server - https://github.com/tepea-code/yaml-schema-router";
    license = licenses.mit;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
  };
}
