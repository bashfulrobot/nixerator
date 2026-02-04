{
  globals,
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.meetsum;
  username = globals.user.name;
  homeDir = "/home/${username}";
  meetsum = pkgs.callPackage ./build { inherit versions; };

  # Generate settings.yaml with proper home path
  settingsYaml = pkgs.writeText "settings.yaml" ''
    # meetsum configuration file
    paths:
      # Base directory for meetings
      file_browser_root_dir: "${homeDir}/Documents/Kong/Meetings"

      # Directory containing the LLM instructions file
      automation_dir: "${homeDir}/.config/meetsum"

      # LLM instructions file name
      instructions_file: "Meeting-summary-llm-instructions.md"

    files:
      # Required files in meeting directory
      transcript: "transcript.txt"

      # Optional context files
      pov_input: "pov-input.md"

    ai:
      # AI provider command to execute
      command: "gemini"

    # Feature flags
    features:
      # Enable trace mode by default
      trace_mode: false

      # Show file browser when no path provided
      file_browser: true

      # Enable markdown preview
      markdown_preview: true

    # Logging configuration
    logging:
      # Output options: screen, file, both
      output: "both"
  '';

in
{
  options = {
    apps.cli.meetsum.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable meetsum - AI-powered meeting summarizer.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ meetsum ];

    home-manager.users.${username} = {
      xdg.configFile."meetsum/Meeting-summary-llm-instructions.md".source =
        ./build/Meeting-summary-llm-instructions.md;
      xdg.configFile."meetsum/settings.yaml".source = settingsYaml;
    };
  };
}
