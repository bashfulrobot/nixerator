{
  lib,
}:

let
  # Context definitions: each key becomes ~/.config/{key}/claude-context/
  # with a .mcp.json (cfg.mcpJson) and an allow list (cfg.permissions).
  # Empty since the Slack MCP was removed: log-support-ticket was its only user.
  contexts = { };

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
