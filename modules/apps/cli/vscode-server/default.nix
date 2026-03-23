{
  inputs,
  lib,
  config,
  ...
}:

{
  imports = [ inputs.nixos-vscode-server.nixosModules.default ];

  options.apps.cli.vscode-server.enable = lib.mkEnableOption "VS Code remote SSH server support";

  config = lib.mkIf config.apps.cli.vscode-server.enable {
    services.vscode-server.enable = true;
  };
}
