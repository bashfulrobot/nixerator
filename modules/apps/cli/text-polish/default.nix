{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.cli.text-polish;

  # Rewrite pipeline shared by the keybind filter and the Ctrl+G editor wrapper:
  # rules, claude isolation, marker extraction, safety filters. One copy, so the
  # two front ends can never drift.
  textPolishCore = pkgs.replaceVars ./scripts/text-polish-core.sh {
    jq = "${pkgs.jq}/bin/jq";
    timeout = "${pkgs.coreutils}/bin/timeout";
    od = "${pkgs.coreutils}/bin/od";
    tr = "${pkgs.coreutils}/bin/tr";
    # Concision/anti-slop rules, single-sourced so the front ends and the
    # claude-code `text-polish` skill can never drift apart.
    rules_file = "${cfg.rulesFile}";
  };

  textPolishScript = pkgs.replaceVars ./scripts/text-polish.sh {
    wl_paste = "${pkgs.wl-clipboard}/bin/wl-paste";
    wl_copy = "${pkgs.wl-clipboard}/bin/wl-copy";
    notify_send = "${pkgs.libnotify}/bin/notify-send";
    wtype = "${pkgs.wtype}/bin/wtype";
    jq = "${pkgs.jq}/bin/jq";
    core = "${textPolishCore}";
  };

  # The host's preferred editor, the fallback when the shell has no
  # VISUAL/EDITOR. Same lookup hosts/qbert/home.nix uses for EDITOR.
  defaultEditor = lib.getExe pkgs.${globals.preferences.editor};

  polishEditorScript = pkgs.replaceVars ./scripts/polish-editor.sh {
    git = "${pkgs.git}/bin/git";
    diff = "${pkgs.diffutils}/bin/diff";
    default_editor = defaultEditor;
    core = "${textPolishCore}";
  };

  # Installed as a command so the path is stable and the script is executable.
  polishEditor = pkgs.runCommand "polish-editor" { } ''
    install -Dm755 ${polishEditorScript} $out/bin/polish-editor
  '';
in
{
  options.apps.cli.text-polish = {
    enable = lib.mkEnableOption "Text polish keyboard shortcut — rewrite selected text via Claude";

    editor.enable = lib.mkEnableOption ''
      the Ctrl+G polish editor for Claude Code without the Hyprland keybind, for a
      headless host. `enable` already includes it'';

    rulesFile = lib.mkOption {
      type = lib.types.path;
      default = ./prompt/concision-rules.md;
      readOnly = true;
      description = ''
        Shared concision/anti-slop rewrite rules. Single source of truth consumed
        by the SUPER+SHIFT+R keybind filter and the Ctrl+G editor wrapper (this
        module) and the claude-code `text-polish` skill (installed into its
        references at activation), so they can never drift.
      '';
    };
  };

  config = lib.mkMerge [
    # The keybind needs Hyprland, so it stays behind the full enable.
    (lib.mkIf cfg.enable {
      home-manager.users.${globals.user.name} = {
        # Declared through hyprflake.hyprland.extraLua (hyprflake writes the file
        # and requires it at the end of hyprland.lua).
        hyprflake.hyprland.extraLua."text-polish" = ''
          hl.bind("SUPER + SHIFT + R",
            hl.dsp.exec_cmd("${pkgs.bash}/bin/bash ${textPolishScript}"))
        '';
      };
    })

    # A terminal editor has no compositor selection for the keybind to grab,
    # so Claude Code prompts are polished through its Ctrl+G external editor
    # instead. Installing polish-editor is all this does: the `claude` fish
    # function in claude-code/cfg/fish.nix finds it on PATH and runs claude with
    # it as VISUAL/EDITOR for that one process. Two modules cannot both define
    # the function, because Nix concatenates the bodies.
    (lib.mkIf (cfg.enable || cfg.editor.enable) {
      home-manager.users.${globals.user.name}.home.packages = [ polishEditor ];
    })
  ];
}
