{
  globals,
  lib,
  config,
  ...
}:

let
  cfg = config.apps.cli.deck;
in
{
  options = {
    apps.cli.deck.enable = lib.mkEnableOption "Kong decK CLI via Docker (kong/deck image)";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      programs.fish.shellAliases = {
        deck = "docker run --rm --network host -v .:/files -w /files kong/deck";
      };
    };
  };
}
