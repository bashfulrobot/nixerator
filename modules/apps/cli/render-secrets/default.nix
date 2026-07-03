{
  globals,
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.render-secrets;

  # External secrets path — kept outside the repo so AI tools scoped to the
  # repo working directory cannot read it, and so secrets never enter the
  # Nix store as a flake input.
  destPath = "${globals.user.homeDirectory}/.config/nixos-secrets/secrets.json";
  tplPath = "${globals.paths.nixerator}/secrets.json.tpl";

  render-secrets =
    pkgs.runCommand "render-secrets"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        src = ./render-secrets.sh;
      }
      ''
        install -Dm755 $src $out/bin/render-secrets
        substituteInPlace $out/bin/render-secrets \
          --replace-fail "@DEST@" "${destPath}" \
          --replace-fail "@TPL@" "${tplPath}"
        wrapProgram $out/bin/render-secrets \
          --prefix PATH : ${
            lib.makeBinPath [
              pkgs._1password-cli
              pkgs.openssh
              pkgs.openssl
              pkgs.diffutils
              pkgs.coreutils
              pkgs.git
            ]
          }
      '';
in
{
  options.apps.cli.render-secrets = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install the render-secrets helper, which renders
        ${globals.paths.nixerator}/secrets.json.tpl through `op inject`
        to ${destPath}.

        Enable on hosts that have the 1Password CLI available (i.e. the
        hosts that will originate `op inject` runs and `--push` to
        headless peers).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ render-secrets ];
  };
}
