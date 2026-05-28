{
  globals,
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.apps.cli.git-cliff;
in
{
  options.apps.cli.git-cliff.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable git-cliff — conventional-commit changelog generator with a shared default cliff.toml.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.git-cliff ];

    # Global default config picked up by `git cliff` when a repo has no
    # cliff.toml of its own. Per-project configs (cliff.toml at repo root,
    # or [package.metadata.git-cliff] in Cargo.toml / pyproject.toml /
    # package.json) still override this one.
    home-manager.users.${globals.user.name}.xdg.configFile."git-cliff/cliff.toml".source = ./cliff.toml;
  };
}
