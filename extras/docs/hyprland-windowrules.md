# Hyprland Window Rules

hyprflake's hyprland module sets `configType = "lua"`, which replaces
`hyprland.conf` with a Lua-driven config end to end. Under this backend,
`.conf` files dropped into `conf.d/` are never read: window rules, binds,
and exec-once-equivalents must be written as Lua and declared through
`hyprflake.hyprland.extraLua`.

## Declaring a snippet

```nix
home-manager.users.${globals.user.name} = {
  hyprflake.hyprland.extraLua."my-app-windowrule" = ''
    hl.window_rule({
      name = "my-app-tile",
      match = { class = "^(MyApp)$" },
      tile = true,
    })
  '';
};
```

`hyprflake.hyprland.extraLua` writes the Lua file and requires it at the
end of `hyprland.lua` for you. A hand-written `xdg.configFile."hypr/conf.d/
<name>.lua"` entry is never sourced this way and will silently do nothing
-- do not use it.

## Window rules

```lua
hl.window_rule({
  name = "my-app-tile",
  match = { class = "^(MyApp)$" },
  tile = true,
})
```

**Required fields:**

- `name` -- unique identifier for the rule
- `match` -- a table with at least one match field

**Common `match` fields:**

| Field       | Description          | Example         |
| ----------- | --------------------- | --------------- |
| `class`     | Window class (regex)  | `^([Mm]orgen)$` |
| `title`     | Window title (regex)  | `^Settings$`    |
| `xwayland`  | XWayland window        | `true`          |
| `float`     | Floating state         | `false`         |
| `workspace` | Workspace match        | `"w[tv1]"`      |

**Common rule fields:**

| Field    | Description    | Example              |
| -------- | --------------- | --------------------- |
| `tile`   | Force tiling    | `true`                |
| `float`  | Force floating  | `true`                |
| `opacity`| Window opacity  | `"0.9 0.8"` (string)  |
| `move`   | Position        | `"20 monitor_h-120"`  |
| `size`   | Window size     | `"800 600"`           |
| `pin`    | Pin to all workspaces | `true`          |

Booleans (`tile`, `float`, `pin`) are Lua `true`/`false`, not the hyprlang
`on`/`off` strings. `opacity`, `move`, and `size` stay strings.

## Keybinds

```lua
hl.bind("SUPER + SHIFT + Z",
  hl.dsp.exec_cmd("my-script"), { description = "Run my script" })
```

## Exec-once equivalents

The Lua backend has no `exec-once` keyword. Run something once at startup
with `hl.on`:

```lua
hl.on("hyprland.start", function() hl.exec_cmd("my-startup-command") end)
```

## Common mistakes

1. **Using hyprlang `windowrule { }` or `windowrulev2 = ...`** -- Both are
   native Hyprland syntax, not Lua. Neither works under `configType = "lua"`.
2. **Dropping a `.conf` (or hand-written `.lua`) file straight into
   `conf.d/`** -- Only files declared via `hyprflake.hyprland.extraLua` get
   required by `hyprland.lua`; anything else in `conf.d/` is inert.
3. **Using `on`/`off` for boolean rule fields** -- Lua wants `true`/`false`.
4. **Missing the `match` table on a window rule** -- every rule needs at
   least one match field inside `match = { ... }`.

## Real examples in this repo

- `modules/apps/cli/text-uppercase/default.nix` -- a keybind via `hl.bind`
- `modules/apps/webapps/zoom/clipboard-join.nix` -- a keybind via `hl.bind`
  + `hl.dsp.exec_cmd`
- `modules/system/special-workspaces/default.nix` -- keybinds driving
  `hl.dsp.workspace.toggle_special`
- `hosts/qbert/home.nix` -- a monitor rule via `hl.monitor`

## Reference

- [Hyprland wiki: Window Rules](https://wiki.hyprland.org/Configuring/Window-Rules/)
  (hyprlang syntax -- useful for field semantics, not Lua syntax)
