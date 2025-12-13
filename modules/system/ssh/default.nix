{ globals, lib, pkgs, config, ... }:

let
  cfg = config.system.ssh;
  username = globals.user.name;
in
{
  options = {
    system.ssh.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable OpenSSH server and client with predefined host configurations.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Enable OpenSSH server
    services.openssh.enable = true;

    # Home Manager SSH client configuration
    home-manager.users.${username} = {

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;

        # Import sensitive host configurations from encrypted file
        # The hosts.nix file is encrypted with git-crypt
        matchBlocks = import ./hosts.nix;
      };
    };
  };
}
