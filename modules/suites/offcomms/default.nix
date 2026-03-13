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
    # Communication applications
    apps.gui = {
      insync.enable = true;
      morgen.enable = false;
      obsidian.enable = true;
      signal.enable = true;
      typora.enable = true;
      typora.nautilusIntegration = true;
      vocalinux.enable = true;
      wayscriber.enable = true;
    };

    # Web apps for office reference desktop
    apps.webapps = {
      mail.enable = true;
      calendar.enable = true;
    };

    # Voxtype voice-to-text (managed by hyprflake)
    hyprflake.desktop.voxtype = {
      enable = true;
      hotkey = "SCROLLLOCK";
      model = lib.mkDefault "base.en";
    };

    apps.cli = {
      meetsum.enable = true;
      pandoc.enable = true;
      percollate.enable = true;
      todoist-report.enable = true;
      wkhtmltopdf.enable = true;
    };

    # Special workspaces for task manager and office apps
    system.special-workspaces.enable = true;

    environment.systemPackages = with pkgs; [
      discord-ptb
      slack
      todoist-electron
      fractal
    ];
  };
}
