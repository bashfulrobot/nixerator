{ pkgs, ... }:

{
  apps.cli = {
    # Render Nix-eval secrets from 1Password on this host. Uses the op CLI and
    # the service-account token; injects secrets into config files only.
    render-secrets.enable = true;
  };

  # 1Password CLI only — no GUI app, so suites.security is deliberately not
  # enabled. Authenticated headlessly via the service-account token at
  # ~/.config/op/service-account-token, which home.nix exports as
  # OP_SERVICE_ACCOUNT_TOKEN in shells.
  environment.systemPackages = [ pkgs._1password-cli ];
}
