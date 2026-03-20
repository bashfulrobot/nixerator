{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.slack-token-refresh;

  slack-token-refresh-pkg = pkgs.buildNpmPackage {
    pname = "slack-token-refresh";
    version = "1.0.0";

    src = ./scripts;

    npmDepsHash = "sha256-aiFNUgo8U6R0Eq7efmaYJ6PDtX6Z0IgcbAfFtjzqSp4=";
    dontNpmBuild = true;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/slack-token-refresh"
      cp -r . "$out/lib/slack-token-refresh"

      mkdir -p "$out/bin"
      makeWrapper "${pkgs.nodejs}/bin/node" "$out/bin/slack-token-refresh" \
        --add-flags "$out/lib/slack-token-refresh/extract.mjs" \
        --set CHROME_PATH "${lib.getExe pkgs.google-chrome}"

      runHook postInstall
    '';

    meta = {
      description = "Extract Slack xoxc/xoxd tokens from Chrome via Playwright";
      platforms = lib.platforms.linux;
      mainProgram = "slack-token-refresh";
    };
  };
in
{
  options.apps.cli.slack-token-refresh.enable =
    lib.mkEnableOption "slack-token-refresh — extract Slack xoxc/xoxd tokens via Playwright";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ slack-token-refresh-pkg ];
  };
}
