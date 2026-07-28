{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.apps.cli.walkr;
  # walkr ships its own flake with an overlay (inputs.walkr.overlays.default
  # adds `walkr` to pkgs) -- consume that directly instead of re-deriving the
  # buildGoModule call here, so the binary and the flake.lock pin are the only
  # place walkr's build gets defined.
  walkr = (pkgs.extend inputs.walkr.overlays.default).walkr;
in
{
  options = {
    apps.cli.walkr.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable walkr, the renderer for hand-authored topic walkthroughs (static wizard-style teaching sites).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ walkr ];
  };
}
