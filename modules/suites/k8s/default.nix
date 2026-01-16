{ globals, lib, pkgs, config, ... }:

let
  cfg = config.suites.k8s;
  username = globals.user.name;
in
{
  options = {
    suites.k8s.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Kubernetes tooling suite.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable kubectl module with OIDC support
    apps.cli.kubectl.enable = true;

    # Kubernetes ecosystem tools
    environment.systemPackages = with pkgs; [
      talosctl             # Talos OS management tool
      omnictl              # Omni CLI
      argocd               # ArgoCD CLI (GitOps)
      argocd-autopilot     # ArgoCD bootstrapping CLI
      cilium-cli           # Cilium networking CLI
      eksctl               # AWS EKS management tool
      fluxcd               # FluxCD GitOps CLI
      kubernetes-helm      # Kubernetes package manager (Helm)
      kubeseal             # K8s secrets management
      kustomize            # Kubernetes configuration management
      minikube             # Local k8s cluster
    ];

    # Home Manager configuration
    home-manager.users.${username} = {
      programs.k9s = {
        enable = true;
      };
    };
  };
}
