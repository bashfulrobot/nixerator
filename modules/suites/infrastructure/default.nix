{ lib, pkgs, config, ... }:

let
  cfg = config.suites.infrastructure;
in
{
  options = {
    suites.infrastructure.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable infrastructure management suite with cloud and IaC tools.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable Docker
    apps.cli.docker.enable = true;

    # Infrastructure and cloud tools
    environment.systemPackages = with pkgs; [
      # Cloud utilities
      cloud-utils          # Cloud management utilities
      cdrtools             # mkisofs needed for cloud-init
      aws-iam-authenticator  # AWS IAM authentication tool
      google-cloud-sdk     # Google Cloud SDK

      # Infrastructure as Code
      terraform            # Infrastructure provisioning
      libxslt              # XSL transformations (used in terraform scripts)

      # Network utilities
      wakeonlan            # Wake on LAN utility
    ];
  };
}
