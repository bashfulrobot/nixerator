{
  lib,
  config,
  pkgs,
  globals,
  ...
}:

let
  cfg = config.dev.go;
in
{
  options = {
    dev.go.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Go tooling with clang support for CGO.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install Go and clang for CGO support
    environment.systemPackages = with pkgs; [
      go
      clang
      llvm
      gotools # goimports, gorename, etc.
      golangci-lint # standard linter
      delve # debugger
    ];

    # Set clang as the default C/C++ compiler for CGO
    environment.variables = {
      CC = "clang";
      CXX = "clang++";
    };

    # Also set for user sessions
    home-manager.users.${globals.user.name} = {
      home.sessionVariables = {
        CC = "clang";
        CXX = "clang++";
        GOPATH = "$HOME/go";
        GOBIN = "$HOME/go/bin";
      };

      home.sessionPath = [ "$HOME/go/bin" ];
    };
  };
}
