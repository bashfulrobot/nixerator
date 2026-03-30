{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.suites.offcomms;
in
{
  options = {
    suites.offcomms.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable communications suite with Signal and other secure messaging applications.";
    };
  };

  config = lib.mkIf cfg.enable {
    apps = {
      # Communication applications
      gui = {
        insync.enable = true;
        localsend.enable = true;
        morgen.enable = true;
        obsidian.enable = true;
        signal.enable = true;
        typora.enable = true;
        typora.nautilusIntegration = true;
        wayscriber.enable = true;
      };

      # Web apps for office reference desktop
      webapps = {
        mail.enable = true;
        calendar.enable = true;
        slack.enable = false;
        zoom.enable = true;
      };

      cli = {
        gurk.enable = true;
        meetsum.enable = true;
        pandoc.enable = true;
        percollate.enable = true;
        slack-token-refresh.enable = true;
        slack-tracker.enable = true;
        todoist-report.enable = true;
        wkhtmltopdf.enable = true;
      };
    };

    # Voxtype voice-to-text (managed by hyprflake)
    hyprflake.desktop.voxtype = {
      enable = true;
      hotkey = "SCROLLLOCK";
      model = lib.mkDefault "base.en";
    };

    # Special workspaces for task manager and office apps
    system.special-workspaces.enable = true;

    environment.systemPackages = with pkgs; [
      discord-ptb
      slack
      todoist-electron
      fractal
      signal-cli
    ];
  };
}
