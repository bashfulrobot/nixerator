# Modules

- Modules auto-import via `modules/default.nix` — never manually import a module elsewhere. Subdirs named `disabled/`, `build/`, `cfg/`, `reference/` are excluded from auto-import; use these for local helpers. Paths containing `/_` are also silently skipped (import-tree upstream default), so `_wip/` etc. is another opt-out option.
- Standard structure: `let cfg = config.NAMESPACE.PATH;` → `options` with `lib.mkEnableOption` → `config = lib.mkIf cfg.enable { ... }`.
- Namespace matches directory path: `apps.cli.*`, `apps.gui.*`, `apps.webapps.*`, `suites.*`, `system.*`, `dev.*`, `server.*`, `archetypes.*`.
- Home Manager config goes inside `home-manager.users.${globals.user.name} = { ... }`.
- Configuration priority: prefer `programs.<name>` or `services.<name>` Home Manager modules first, then NixOS options, then `xdg.configFile`/`xdg.dataFile` as a last resort.
- Guard secrets access: `lib.optionalAttrs (secrets.foo or null != null) { ... }`.
- Hyprland config (keybinds, windowrules, exec-once-equivalents, env vars) uses `hyprflake.hyprland.extraLua."<name>"` (a string of Lua) inside a `home-manager.users` block. Do not use `hyprflake.desktop.autostartD`, `wayland.windowManager.hyprland.settings`, or a raw `xdg.configFile."hypr/conf.d/<name>.lua"` — hyprflake writes and requires the file for you; a hand-written `xdg.configFile` entry there is never sourced by `hyprland.lua` and silently does nothing.
- Hyprflake's hyprland module sets `configType = "lua"`. Snippets must be **Lua** (`hl.bind(...)`, `hl.window_rule({...})`, `hl.on("hyprland.start", function() hl.exec_cmd(...) end)`).
- For window rules use `hl.window_rule({name=..., match={...}, <effect>=<value>})`. `opacity` is a string (`"0.9 0.9"`), booleans like `tile`/`float`/`pin` are `true`/`false`. Never use hyprlang `windowrule = ...` or `windowrulev2` syntax.
- For "exec-once" use `hl.on("hyprland.start", function() hl.exec_cmd(...) end)`. The Lua backend has no `exec-once` keyword.
