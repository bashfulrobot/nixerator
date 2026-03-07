{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.system.apple-fonts;
  appleFontsPkgs = inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system};

  # Fix undmg linker ordering: libraries must come after object files
  fixedUndmg = pkgs.undmg.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace Makefile \
        --replace-fail '$(LD) $(LDFLAGS) $(LIB) $^ -o $@' \
                       '$(LD) $(LDFLAGS) $^ $(LIB) -o $@'
    '';
  });

  fixFont =
    pkg:
    pkg.overrideAttrs (old: {
      buildInputs = map (dep: if dep ? pname && dep.pname == "undmg" then fixedUndmg else dep) (
        old.buildInputs or [ ]
      );
    });
in
{
  options = {
    system.apple-fonts = {
      enable = lib.mkEnableOption "Apple fonts (SF Pro, SF Mono Nerd, New York)";

      packages = {
        sf-pro = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          default = fixFont appleFontsPkgs.sf-pro;
          description = "SF Pro font package (with undmg linker fix applied).";
        };
        sf-mono-nerd = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          default = fixFont appleFontsPkgs.sf-mono-nerd;
          description = "SF Mono Nerd font package (with undmg linker fix applied).";
        };
        ny = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          default = fixFont appleFontsPkgs.ny;
          description = "New York font package (with undmg linker fix applied).";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = [
      cfg.packages.sf-pro
      cfg.packages.sf-mono-nerd
      cfg.packages.ny
    ];
  };
}
