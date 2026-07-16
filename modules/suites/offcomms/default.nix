{
  lib,
  config,
  globals,
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
        cauldron.enable = true;
        insync.enable = true;
        localsend.enable = true;
        obsidian.enable = true;
        signal.enable = true;
        typora.enable = true;
        typora.nautilusIntegration = true;
      };

      # Web apps for office reference desktop
      webapps = {
        calendar.enable = true;
        zoom.enable = true;
      };

      cli = {
        gmailctl.enable = true;
        gurk.enable = true;
        meetsum.enable = true;
        pandoc.enable = true;
        percollate.enable = true;
        signal-cli.enable = true;
        slack-token-refresh.enable = true;
        slack-tracker.enable = true;
        sheets.enable = true;
        slidev.enable = true;
        todoist-cli.enable = true;
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
      # No native Discord client, deliberately. Both candidates drag an EOL
      # dependency that blocks the system rebuild: vesktop is pinned to
      # electron_40 in nixpkgs (flagged EOL as of nixpkgs 753cc8a3, see
      # NixOS/nixpkgs#542512), and discord-ptb's prebuilt binary still links
      # against openssl 1.1. Neither is worth a permittedInsecurePackages
      # entry, since both render untrusted remote content. Use a
      # browser-wrapped web app (apps.webapps) if Discord is wanted again.
      slack
      todoist-electron
      # Native Zoom client disabled in favour of the browser-wrapped Zoom web
      # app (apps.webapps.zoom). Re-add `zoom-us` here to restore the desktop client.
      # zoom-us
    ];

    # Force Todoist Electron to use native Wayland (avoids XWayland key
    # passthrough that breaks Voxtype push-to-talk suppression)
    home-manager.users.${globals.user.name} = {
      xdg.desktopEntries.todoist = {
        name = "Todoist";
        exec = "todoist-electron --ozone-platform=wayland ---electron -- --no-sandbox %U";
        terminal = false;
        icon = "todoist";
        comment = "The Best To-Do List App & Task Manager";
        categories = [ "Office" ];
        mimeType = [
          "x-scheme-handler/todoist"
          "x-scheme-handler/com.todoist"
        ];
        settings = {
          StartupWMClass = "Todoist";
        };
      };
    };
  };
}
