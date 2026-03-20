{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.slack-tracker;

  libTokenSh = builtins.readFile ./scripts/lib-token.sh;
  libApiSh = builtins.readFile ./scripts/lib-api.sh;
  libUiSh = builtins.readFile ./scripts/lib-ui.sh;

  slack-tracker = pkgs.writeShellApplication {
    name = "slack-tracker";
    runtimeInputs = with pkgs; [
      curl
      jq
      gum
      google-chrome
      xdg-utils
      coreutils
      gnugrep
      gnused
    ];
    text = ''
      ${libTokenSh}
      ${libApiSh}
      ${libUiSh}
      ${builtins.readFile ./scripts/slack-tracker.sh}
    '';
  };
in
{
  options.apps.cli.slack-tracker.enable =
    lib.mkEnableOption "slack-tracker CLI tool for finding unanswered Slack messages";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ slack-tracker ];
  };
}
