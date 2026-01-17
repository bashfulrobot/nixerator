{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.kubectl;
  username = globals.user.name;
in
{
  options = {
    apps.cli.kubectl.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable kubectl with OIDC authentication support.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      kubectl              # Kubernetes command-line tool
      kubecolor            # Colorize kubectl output
      kubelogin            # Azure/OIDC login
      kubelogin-oidc       # OIDC authentication for kubectl
      krew                 # kubectl plugin manager
      ktop                 # K8s top command
    ];

    # Home Manager configuration for kubectl aliases
    # kubecolor is a wrapper that colorizes kubectl output
    home-manager.users.${username} = {
      programs.fish = {
        shellAliases = {
          k = "kubecolor";
          kubectl = "kubecolor";
        };
      };
    };
  };
}
