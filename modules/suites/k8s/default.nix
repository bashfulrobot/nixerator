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
      # argocd            # ArgoCD CLI (GitOps) - temporarily disabled due to nixpkgs yarn hash mismatch
      # argocd-autopilot  # ArgoCD bootstrapping CLI - depends on argocd
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
            # argo = "argocd"; # temporarily disabled because argocd package is disabled above
            kz = "kustomize";
          };
          functions = {
            kns-force-delete = {
              description = "Force delete a namespace, clearing finalizers if stuck";
              body = ''
                set -l ns
                if test (count $argv) -eq 0
                    set ns (kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | fzf --header="Select namespace to force delete")
                    if test -z "$ns"
                        echo "No namespace selected"
                        return 1
                    end
                else
                    set ns $argv[1]
                end
                echo "Deleting namespace: $ns"
                kubectl delete namespace $ns --wait=false
                echo "Clearing finalizers..."
                kubectl get namespace $ns -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f -
              '';
            };
          };
        };
      };
    };
  };
}
