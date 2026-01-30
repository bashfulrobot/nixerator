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
      programs = {
        k9s = {
          enable = true;
        };

        fish = {
          shellAliases = {
            h = "helm";
            t = "talosctl";
            o = "omnictl";
            mk = "minikube";
            argo = "argocd";
            kz = "kustomize";
          };
          functions = {
            kns-force-delete = {
              description = "Force delete a namespace stuck in Terminating state";
              body = ''
                if test (count $argv) -eq 0
                    echo "Usage: kns-force-delete <namespace>"
                    return 1
                end
                kubectl get namespace $argv[1] -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$argv[1]/finalize" -f -
              '';
            };
          };
        };
      };
    };
  };
}
