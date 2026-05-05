# Modules

- Modules auto-import via `modules/default.nix` — never manually import a module elsewhere. Subdirs named `disabled/`, `build/`, `cfg/`, `reference/` are excluded from auto-import; use these for local helpers.
- Standard structure: `let cfg = config.NAMESPACE.PATH;` → `options` with `lib.mkEnableOption` → `config = lib.mkIf cfg.enable { ... }`.
- Namespace matches directory path: `apps.cli.*`, `apps.gui.*`, `apps.webapps.*`, `suites.*`, `system.*`, `dev.*`, `server.*`, `archetypes.*`.
- Home Manager config goes inside `home-manager.users.${globals.user.name} = { ... }`.
- Configuration priority: prefer `programs.<name>` or `services.<name>` Home Manager modules first, then NixOS options, then `xdg.configFile`/`xdg.dataFile` as a last resort.
- Guard secrets access: `lib.optionalAttrs (secrets.foo or null != null) { ... }`.
- Hyprland config (keybinds, windowrules, exec-once, env vars) uses the conf.d drop-in pattern: `xdg.configFile."hypr/conf.d/<name>.conf"` inside a `home-manager.users` block. Do not use `hyprflake.desktop.autostartD` or `wayland.windowManager.hyprland.settings`.
- Window rules MUST use block syntax (Hyprland 0.53+). Never use `windowrulev2` or single-line `windowrule =` for rules with values. See `extras/docs/hyprland-windowrules.md`.
