{
  lib,
  pkgs,
  config,
  inputs,
  globals,
  ...
}:

let
  cfg = config.apps.cli.llmfit;
  # Override with corrected Cargo.lock (upstream is missing arboard dependency)
  llmfit-pkg = inputs.llmfit.packages.x86_64-linux.default.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      cp ${./Cargo.lock} Cargo.lock
    '';
    cargoDeps = pkgs.rustPlatform.importCargoLock {
      lockFile = ./Cargo.lock;
    };
  });
in
{
  options.apps.cli.llmfit = {
    enable = lib.mkEnableOption "llmfit TUI for matching LLM models to hardware capabilities";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [
        llmfit-pkg
      ];
    };
  };
}
