{
  lib,
  config,
  globals,
  ...
}:

let
  cfg = config.system.special-workspaces;
in
{
  options.system.special-workspaces.enable = lib.mkEnableOption "Hyprland special workspaces for task, office, music, and dev apps";

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      xdg.configFile."hypr/conf.d/special-workspaces.conf".text = ''
        # Special Workspaces: named special workspaces toggled by shortcut
        # SUPER+W = Work, SUPER+O = Office, SUPER+M = Music, SUPER+D = Dev

        # Keybinds: toggle and move-to
        bind = SUPER, W, togglespecialworkspace, work
        bind = SUPER SHIFT, W, movetoworkspace, special:work
        bind = SUPER, O, togglespecialworkspace, office
        bind = SUPER SHIFT, O, movetoworkspace, special:office
        bind = SUPER, M, togglespecialworkspace, music
        bind = SUPER SHIFT, M, movetoworkspace, special:music
        bind = SUPER, D, togglespecialworkspace, dev
        bind = SUPER SHIFT, D, movetoworkspace, special:dev

        # Window rules: assign apps to their special workspace on launch
        windowrule {
            name = todoist-to-work
            match:class = ^(todoist)$
            workspace = special:work
        }

        windowrule {
            name = slack-to-office
            match:class = ^(Slack)$
            workspace = special:office
        }

        windowrule {
            name = morgen-to-office
            match:class = ^([Mm]orgen)$
            workspace = special:office
        }

        windowrule {
            name = gmail-to-office
            match:class = ^(chrome-mail\.google\.com__mail_u_1_-Default)$
            workspace = special:office
        }

        windowrule {
            name = gcal-to-office
            match:class = ^(chrome-calendar\.google\.com__calendar_u_1_r-Default)$
            workspace = special:office
        }

        # Auto-launch apps onto their special workspaces
        exec-once = todoist-electron
        exec-once = slack
        exec-once = morgen
        exec-once = google-chrome-stable --no-first-run --app="https://mail.google.com/mail/u/1/#search/is%3Aunread+in%3Ainbox" --class=chrome-mail.google.com__mail_u_1_-Default --name=chrome-mail.google.com__mail_u_1_-Default
        exec-once = google-chrome-stable --no-first-run --app="https://calendar.google.com/calendar/u/1/r" --class=chrome-calendar.google.com__calendar_u_1_r-Default --name=chrome-calendar.google.com__calendar_u_1_r-Default
      '';
    };
  };
}
