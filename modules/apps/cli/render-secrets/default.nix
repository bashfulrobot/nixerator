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
          --replace-fail "@TPL@" "${tplPath}" \
          --replace-fail "@MAP@" "${./gopass-map.tsv}" \
          --replace-fail "@DOCS@" "${./gopass-documents.psv}"
        wrapProgram $out/bin/render-secrets \
          --prefix PATH : ${
            lib.makeBinPath [
              pkgs._1password-cli
              pkgs.openssh
              pkgs.diffutils
              pkgs.coreutils
              pkgs.git
              pkgs.jq # forgejo tea-config generation reads .forgejo.apiToken; --from gopass builds the file with it
              pkgs.gopass # --from gopass reads the secauto store
              pkgs.gnupg # gopass shells out to gpg to decrypt
              pkgs.gawk # --from gopass looks references up in the shared map
              pkgs.gnugrep
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
        headless peers). `render-secrets --from gopass` fills the same
        template from the secauto gopass store with no 1Password at all,
        so a headless host can enable this module and render by itself.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ render-secrets ];
  };
}
