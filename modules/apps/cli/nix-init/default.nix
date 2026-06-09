{
  globals,
  lib,
  config,
  ...
}:

let
  cfg = config.apps.cli.nix-init;
in
{
  options = {
    apps.cli.nix-init.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable nix-init, a CLI that scaffolds a Nix derivation from a URL — it detects the build system and prefetches source and dependency hashes (cargoHash/vendorHash). Authoring aid only; adapt its output to the repo's versions.nix + build/ layout.";
    };
  };

  config = lib.mkIf cfg.enable {

    home-manager.users.${globals.user.name} = {

      programs.nix-init = {
        enable = true;
        settings = {
          # Stamp generated `meta.maintainers` with the repo owner.
          maintainers = [ "bashfulrobot" ];

          # This host runs `nix.nixPath = [ ]`, so the upstream default of
          # `<nixpkgs>` does not resolve. Pull nixpkgs from the flake registry
          # instead (the documented flake-host setting).
          nixpkgs = ''builtins.getFlake "nixpkgs"'';

          # The user owns commits; never let nix-init auto-commit generated files.
          commit = false;
        };
      };

    };

  };
}
