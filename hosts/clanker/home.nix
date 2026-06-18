{
  pkgs,
  lib,
  globals,
  ...
}:

{
  home = {
    username = globals.user.name;
    inherit (globals.user) homeDirectory;
    inherit (globals.defaults) stateVersion;

    packages = with pkgs; [
      # Minimal headless desktop tooling
      foot # terminal launched into the Sway session (super+t, or by Claude)
      grim # wlroots screenshot grabber
      slurp # region select for grim
      wl-clipboard # wl-copy/wl-paste for the Wayland session
      # General CLI niceties
      htop
      tree
      ripgrep
      fd
      bat
    ];

    sessionVariables = {
      EDITOR = lib.mkForce (lib.getExe pkgs.${globals.preferences.editor});
    };
  };

  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
    enableCompletion = true;
  };

  # --- Fish: autostart headless Sway, bridge SSH shells, unlock op ---
  programs.fish = {
    # On TTY1, the login shell starts the headless Sway session. The wlroots
    # headless backend creates a virtual output with no display device, which
    # grim captures. Guarded on XDG_VTNR=1 so SSH and other TTYs never exec
    # sway. If sway exits, the tty session ends, getty respawns, and autologin
    # restarts it — a self-healing always-up session.
    loginShellInit = ''
      if status is-login; and test -z "$WAYLAND_DISPLAY"; and test "$XDG_VTNR" = 1
          set -gx WLR_BACKENDS headless
          set -gx WLR_LIBINPUT_NO_DEVICES 1
          exec sway
      end
    '';

    interactiveShellInit = ''
      # Bridge SSH shells to the running headless Sway session so grim and GUI
      # launches target it with no manual env setup.
      if set -q SSH_CONNECTION; and not set -q WAYLAND_DISPLAY
          set -l rt /run/user/(id -u)
          if test -d "$rt"
              set -l sock (command ls $rt/wayland-* 2>/dev/null | string match -rv '\.lock$' | head -n1)
              if test -n "$sock"
                  set -gx XDG_RUNTIME_DIR $rt
                  set -gx WAYLAND_DISPLAY (basename $sock)
              end
          end
      end

      # Make `op` authenticated from boot via the service-account token
      # (installed once with `just setup-op-token`). Enables headless op/direnv.
      if not set -q OP_SERVICE_ACCOUNT_TOKEN; and test -r ~/.config/op/service-account-token
          set -gx OP_SERVICE_ACCOUNT_TOKEN (cat ~/.config/op/service-account-token)
      end
    '';
  };

  # --- Minimal headless Sway: one terminal keybind, a fixed virtual output ---
  wayland.windowManager.sway = {
    enable = true;
    config = {
      modifier = "Mod4";
      terminal = "foot";
      bars = [ ]; # no status bar
      startup = [ ]; # nothing auto-starts
      keybindings = lib.mkOptionDefault {
        "Mod4+t" = "exec foot";
      };
      # Fixed-size virtual output for the headless backend; gives grim a
      # deterministic canvas.
      output."HEADLESS-1".resolution = "1920x1080";
    };
    # No swayidle / swaylock configured, so the session never blanks or locks.
  };
}
