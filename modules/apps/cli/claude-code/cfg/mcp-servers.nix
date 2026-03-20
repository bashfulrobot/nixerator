{
  lib,
  pkgs,
  secrets,
  kubernetesMcpServer,
  kubeconfigFile,
}:

let
  context7ApiKey = (secrets.context7 or { }).apiKey or null;

  mcpServers = {
    kubernetes-mcp-server = {
      command = "${kubernetesMcpServer}/bin/kubernetes-mcp-server";
      args = [ "--read-only" ];
      env = {
        KUBECONFIG = kubeconfigFile;
      };
    };
    # Go code intelligence via official gopls MCP (detached mode)
    # Tools: go_diagnostics, go_references, go_search, go_symbol_references, etc.
    gopls = {
      command = "${pkgs.gopls}/bin/gopls";
      args = [ "mcp" ];
    };
    slack = {
      type = "http";
      url = "https://mcp.slack.com/mcp";
      oauth = {
        clientId = "1601185624273.8899143856786";
        callbackPort = 3118;
      };
    };
    todoist = {
      type = "http";
      url = "https://ai.todoist.net/mcp";
    };
    # Chrome DevTools for coding agents — browser automation, debugging, screenshots
    chrome-devtools = {
      command = "${pkgs.nodejs}/bin/npx";
      args = [
        "-y"
        "chrome-devtools-mcp@latest"
      ];
    };
  }
  // lib.optionalAttrs (context7ApiKey != null) {
    context7 = {
      type = "http";
      url = "https://mcp.context7.com/mcp";
      headers = {
        CONTEXT7_API_KEY = context7ApiKey;
      };
    };
  }
  // lib.optionalAttrs (secrets.kong.kongKonnectPAT or null != null) {
    kong-konnect = {
      type = "http";
      url = "https://us.mcp.konghq.com/";
      headers = {
        Authorization = "Bearer ${secrets.kong.kongKonnectPAT}";
      };
    };
  };

  mkMcpServerJson =
    name: cfg:
    builtins.toJSON {
      mcpServers = {
        "${name}" = cfg;
      };
    };

  files = lib.mapAttrs' (name: cfg: {
    name = ".claude/mcp-servers/${name}/.mcp.json";
    value = {
      text = mkMcpServerJson name cfg;
    };
  }) mcpServers;
in
{
  inherit mcpServers files;
}
