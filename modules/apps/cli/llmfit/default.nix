{
  lib,
  config,
  inputs,
  globals,
  ...
}:

let
  cfg = config.apps.cli.llmfit;
  llmfit-pkg = inputs.llmfit.packages.x86_64-linux.default;
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
