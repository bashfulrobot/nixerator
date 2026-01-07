{
  config,
  lib,
  pkgs,
  globals,
  secrets,
  ...
}:
let
  cfg = config.apps.cli.codex;
  username = globals.user.name;
in
{
  options = { # Changed from options.apps.cli.codex = {
    apps.cli.codex = {
      enable = lib.mkEnableOption "Codex CLI tool";
    };
  };

  config = lib.mkIf cfg.enable {
    # System packages for MCP server dependencies
    environment.systemPackages = with pkgs; [
      nodejs_24 # Includes npm and npx for MCP servers
    ];

    home-manager.users.${username} = {
      programs.codex = {
        enable = true;

        # Custom instructions (written to ~/.codex/AGENTS.md)
        custom-instructions = builtins.readFile ./CODEX.md;

        # Settings (TOML config)
        settings = {
          # MCP Servers (Model Context Protocol integrations)
          mcp_servers = {
            sequential-thinking = {
              command = "${pkgs.nodejs_24}/bin/npx";
              args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
            };
          } // lib.optionalAttrs (secrets.kong.kongKonnectPAT or null != null) {
            kong-konnect = {
              url = "https://us.mcp.konghq.com/";
              http_headers = {
                Authorization = "Bearer ${secrets.kong.kongKonnectPAT}";
              };
            };
          };
        };
      };
    };
  };
}
