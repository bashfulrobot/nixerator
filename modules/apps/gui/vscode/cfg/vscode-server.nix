{ inputs, ... }:
{
  imports = [ inputs.nixos-vscode-server.nixosModules.default ];
}

