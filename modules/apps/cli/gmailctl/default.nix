{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.apps.cli.gmailctl;
in
{
  options = {
    apps.cli.gmailctl.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable gmailctl - declarative Gmail filters/labels (jsonnet).

        Rules live in the ~/git/gmail-filters repo and are read from
        ~/.gmailctl/config.jsonnet. The OAuth *client* credentials
        (~/.gmailctl/credentials.json) are NOT in the Nix store - fetch them
        from the nixerator 1Password vault with `just fetch-gmailctl-creds`,
        then run `gmailctl init` once to complete the browser consent and
        create ~/.gmailctl/token.json.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.gmailctl ];
  };
}
