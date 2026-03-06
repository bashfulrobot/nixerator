# Module Development

## Quick Start

1. Create directory: `modules/apps/cli/APPNAME/`
2. Create `default.nix` with module pattern (see templates below)
3. Enable in host or suite: `apps.cli.APPNAME.enable = true;`
4. Rebuild  -- no manual imports needed (auto-discovery)

## Templates

### CLI App

```nix
{ lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.APPNAME;
in
{
  options.apps.cli.APPNAME.enable = lib.mkEnableOption "APPNAME";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.APPNAME ];
  };
}
```

### GUI App (with Home Manager)

```nix
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.gui.APPNAME;
in
{
  options.apps.gui.APPNAME.enable = lib.mkEnableOption "APPNAME";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.APPNAME ];
    home-manager.users.${globals.user.name} = {
      home.file.".config/APPNAME/config.conf".text = ''
        # Configuration here
      '';
    };
  };
}
```

### Web App

```nix
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.webapps.APPNAME;
in
{
  options.apps.webapps.APPNAME.enable = lib.mkEnableOption "APPNAME";

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      xdg.desktopEntries.APPNAME = {
        name = "APPNAME";
        exec = "${pkgs.google-chrome}/bin/google-chrome-stable --app=https://APPNAME.com";
        icon = "web-browser";
        categories = [ "Network" "WebBrowser" ];
      };
    };
  };
}
```

### Suite

```nix
{ lib, config, ... }:

let
  cfg = config.suites.SUITENAME;
in
{
  options.suites.SUITENAME.enable = lib.mkEnableOption "SUITENAME suite";

  config = lib.mkIf cfg.enable {
    apps.cli.tool1.enable = true;
    apps.gui.app1.enable = true;
  };
}
```

### Module-Local Package (build/)

Place derivation in `build/default.nix` next to the module, call with `pkgs.callPackage ./build { };`.

### Secrets

Access via `secrets` special arg: `secrets.newservice.api_key`. Guard with `lib.optionalAttrs (secrets.x or null != null) { ... };`.

### Custom Options

Use `lib.mkOption` for extra config beyond `enable`. See `modules/apps/cli/` for examples.

## Categories

| Type | Path | Option prefix |
|------|------|---------------|
| CLI App | `modules/apps/cli/<name>/` | `apps.cli.<name>` |
| GUI App | `modules/apps/gui/<name>/` | `apps.gui.<name>` |
| Web App | `modules/apps/webapps/<name>/` | `apps.webapps.<name>` |
| Suite | `modules/suites/<name>/` | `suites.<name>` |
| System | `modules/system/<name>/` | `system.<name>` |
| Server | `modules/server/<name>/` | `server.<name>` |
| Dev | `modules/dev/<name>/` | `dev.<name>` |

## Hyprland Configuration

Hyprland config (keybinds, window rules, exec-once, env vars) uses the conf.d drop-in pattern:

```nix
home-manager.users.${globals.user.name} = {
  xdg.configFile."hypr/conf.d/<name>.conf".text = ''
    # Hyprland config here
  '';
};
```

Do not use `wayland.windowManager.hyprland.settings`. Window rules must use block syntax (Hyprland 0.53+). See `extras/docs/hyprland-windowrules.md` for syntax reference.

## Common Patterns

- **Globals**: `globals.user.name`, `globals.paths.nixerator`, `globals.defaults.locale`, `globals.preferences.editor`
- **System packages**: `environment.systemPackages = [ pkgs.foo ];`
- **User packages**: `home-manager.users.${globals.user.name}.home.packages = [ pkgs.foo ];`
- **Config files**: `home.file.".config/app/config.conf".source = ./config.conf;`
- **Services**: `systemd.services.myservice` (system) or `systemd.user.services.myservice` (HM)

## Auto-Import Exclusions

Excluded dirs: `disabled/`, `build/`, `cfg/`, `reference/`. To temporarily disable a module, move it to a `disabled/` subdirectory.

## Testing

```bash
nix-instantiate --parse modules/apps/cli/APPNAME/default.nix   # syntax check
sudo nixos-rebuild build --flake .#HOSTNAME                     # build without activating
sudo nixos-rebuild switch --flake .#HOSTNAME                    # apply
```

## Checklist

- [ ] Module directory in correct location
- [ ] `default.nix` with options + config
- [ ] (Optional) `build/default.nix` for local derivation
- [ ] Added to suite or host `modules.nix`
- [ ] Tested with `nixos-rebuild build`
- [ ] Secrets documented if needed

## Reference Modules

- Simple CLI: `modules/apps/cli/zoxide/default.nix`
- GUI with config: `modules/apps/gui/google-chrome/default.nix`
- Suite: `modules/suites/dev/default.nix`
- System service: `modules/apps/cli/tailscale/default.nix`
- Web app: `modules/apps/webapps/calendar/default.nix`
