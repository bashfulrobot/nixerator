{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.ollama;
  username = globals.user.name;
  accelerationPackages = {
    cpu = pkgs.ollama-cpu;
    cuda = pkgs.ollama-cuda;
    rocm = pkgs.ollama-rocm;
    vulkan = pkgs.ollama-vulkan;
  };
  selectedPackage =
    if cfg.acceleration == null
    then pkgs.ollama
    else accelerationPackages.${cfg.acceleration};
in
{
  options = {
    apps.cli.ollama = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Ollama local LLM server.";
      };

      acceleration = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "cpu" "cuda" "rocm" "vulkan" ]);
        default = null;
        description = "Select the Ollama acceleration backend (null uses default package).";
      };

      loadModels = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Models to prefetch and load at service start.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ selectedPackage ];

    services.ollama = {
      enable = true;
      package = selectedPackage;
      loadModels = cfg.loadModels;
    };

    home-manager.users.${username} = {
      programs.fish.shellAliases = {
        glm = "ollama launch claude --model glm-5:cloud";
      };
    };
  };
}
