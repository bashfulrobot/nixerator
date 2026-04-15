{
  lib,
  mcpServers,
}:

let
  # Reuse the Slack MCP config from mcp-servers.nix
  slackMcpJson = builtins.toJSON {
    mcpServers = {
      inherit (mcpServers) slack;
    };
  };

  # Context definitions: each key becomes ~/.config/{key}/claude-context/
  contexts = {
    log-support-ticket = {
      mcpJson = slackMcpJson;
      permissions = [
        "mcp__slack__slack_read_thread"
        "mcp__slack__slack_read_channel"
        "mcp__slack__slack_search_channels"
      ];
    };
  };

  # Generate Home Manager file entries for each context
  mkContextFiles =
    name: cfg:
    let
      prefix = ".config/${name}/claude-context";
    in
    {
      "${prefix}/.mcp.json" = {
        text = cfg.mcpJson;
      };
      "${prefix}/.claude/settings.local.json" = {
        text = builtins.toJSON {
          permissions = {
            allow = cfg.permissions;
          };
        };
      };
    };

  files = lib.foldl' (acc: name: acc // mkContextFiles name contexts.${name}) { } (
    builtins.attrNames contexts
  );
in
{
  inherit files;
}
