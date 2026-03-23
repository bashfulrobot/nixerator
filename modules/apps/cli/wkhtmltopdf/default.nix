{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.apps.cli.wkhtmltopdf;

  wkhtmltopdfDomain = pkgs.writeShellApplication {
    name = "wkhtmltopdf-domain";
    runtimeInputs = with pkgs; [
      wkhtmltopdf
      curl
      wget
      coreutils
      gnused
      gawk
      gnugrep
      findutils
    ];
    text = builtins.readFile ./scripts/wkhtmltopdf-domain.sh;
  };
in
{
  options = {
    apps.cli.wkhtmltopdf.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable wkhtmltopdf and the wkhtmltopdf-domain helper.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      wkhtmltopdf
      wkhtmltopdfDomain
    ];
  };
}
