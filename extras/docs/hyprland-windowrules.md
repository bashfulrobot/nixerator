# Hyprland Window Rules

## Syntax (0.53+)

Hyprland 0.53+ uses a **block syntax** for window rules. The old single-line
`windowrulev2 = RULE, MATCH` syntax is deprecated and will error.

### Block syntax

```
windowrule {
    name = my-rule-name
    match:class = ^(MyApp)$
    tile = on
}
```

**Required fields:**

- `name` -- unique identifier for the rule
- At least one `match:` field

**Common match fields:**

| Field             | Description          | Example         |
| ----------------- | -------------------- | --------------- |
| `match:class`     | Window class (regex) | `^([Mm]orgen)$` |
| `match:title`     | Window title (regex) | `^Settings$`    |
| `match:xwayland`  | XWayland window      | `true`          |
| `match:float`     | Floating state       | `false`         |
| `match:workspace` | Workspace match      | `w[tv1]`        |

**Common rule fields:**

| Field            | Description     | Example            |
| ---------------- | --------------- | ------------------ |
| `tile`           | Force tiling    | `on`               |
| `float`          | Force floating  | `on`               |
| `opacity`        | Window opacity  | `0.9 0.8`          |
| `move`           | Position        | `20 monitor_h-120` |
| `size`           | Window size     | `800 600`          |
| `suppress_event` | Suppress events | `maximize`         |

## conf.d Pattern

Window rules go in `xdg.configFile."hypr/conf.d/<name>.conf"` inside a
`home-manager.users` block. Do not use `wayland.windowManager.hyprland.settings`.

### Example module

```nix
home-manager.users.${globals.user.name} = {
  xdg.configFile."hypr/conf.d/morgen-windowrule.conf".text = ''
    windowrule {
        name = morgen-tile
        match:class = ^([Mm]orgen)$
        tile = on
    }
  '';
};
```

## Common mistakes

1. **Using `windowrulev2`** -- Deprecated. Use `windowrule { }` block syntax.
2. **Using single-line syntax** -- `windowrule = tile, class:Foo` no longer works
   for rules that take values. Use block syntax instead.
3. **Missing `name` field** -- Every windowrule block needs a unique `name`.
4. **Missing value on rule fields** -- Fields like `tile` require a value
   (e.g., `tile = on`, not just `tile`).

## Flat syntax (still works for simple directives)

Some Hyprland directives still accept flat key-value syntax:

```
exec-once = insync start --no-daemon
bind = SUPER CTRL, S, exec, my-script
```

These do not need block syntax. Only `windowrule` requires the block format.

## Reference

- [Hyprland wiki: Window Rules](https://wiki.hyprland.org/Configuring/Window-Rules/)
- Working examples in `~/.config/hypr/hyprland.conf.backup`
