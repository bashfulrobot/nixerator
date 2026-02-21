{ pkgs, config, lib, globals, ... }:
let
  cfg = config.server.whisper-server;

  whisperPkg = pkgs.whisper-cpp.override {
    vulkanSupport = cfg.vulkan;
  };
in
{
  options = {
    server.whisper-server = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable whisper.cpp HTTP server for remote transcription.";
      };

      model = lib.mkOption {
        type = lib.types.str;
        default = "ggml-large-v3-turbo.bin";
        example = "ggml-base.en.bin";
        description = "Whisper model filename (relative to modelDir).";
      };

      modelDir = lib.mkOption {
        type = lib.types.str;
        default = "${globals.user.homeDirectory}/.local/share/voxtype/models";
        description = "Directory containing whisper model files.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Address to bind the whisper server to.";
      };

      port = lib.mkOption {
        type = lib.types.int;
        default = 8080;
        description = "Port for the whisper server.";
      };

      vulkan = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Vulkan GPU acceleration for whisper.cpp.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ whisperPkg ];

    networking.firewall.allowedTCPPorts = [ cfg.port ];

    systemd.services.whisper-server = {
      description = "whisper.cpp HTTP transcription server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = globals.user.name;
        Group = "users";
        ExecStart = "${whisperPkg}/bin/whisper-server -m ${cfg.modelDir}/${cfg.model} --host ${cfg.host} --port ${toString cfg.port}";
        Restart = "on-failure";
        RestartSec = 10;
      };
    };
  };
}
