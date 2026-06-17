{
  lib,
  pkgs,
  secrets,
  kubernetesMcpServer,
  kubeconfigFile,
  serverProfile,
}:

let
  context7ApiKey = (secrets.context7 or { }).apiKey or null;

  mcpServers = {
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
    # Atlassian Remote MCP Server (Rovo) -- Jira / Confluence access.
    # Streamable-HTTP "authv2" endpoint; the legacy /v1/sse endpoint is
    # deprecated after 2026-06-30, so we pin the HTTP one. Auth is OAuth 2.1
    # with dynamic client registration (no clientId to pre-register) -- run
    # `/mcp` in Claude Code to complete the browser authorization flow.
    atlassian = {
      type = "http";
      url = "https://mcp.atlassian.com/v1/mcp/authv2";
    };
    # Tactiq Remote MCP -- meeting transcripts, summaries, and recordings.
    # Streamable-HTTP endpoint is the bare host (paths 404). Auth is OAuth 2.1
    # with discovery-based dynamic client registration (no clientId to
    # pre-register) -- run `/mcp` in Claude Code to complete the browser
    # authorization flow.
    tactiq = {
      type = "http";
      url = "https://mcp.tactiq.io";
    };
    # On-device search engine for notes, transcripts, docs (BM25 + vector + LLM re-ranking)
    qmd = {
      command = "${pkgs.nodejs}/bin/npx";
      args = [
        "-y"
        "@tobilu/qmd"
        "mcp"
      ];
    };
    # GitMCP -- query docs, code, and READMEs of any public GitHub repo on demand.
    # The /docs endpoint is the generic/dynamic entry point; per-repo URLs of the
    # form https://gitmcp.io/{owner}/{repo} also exist if a single repo is wanted.
    gitmcp = {
      type = "http";
      url = "https://gitmcp.io/docs";
    };
  }
  // lib.optionalAttrs (serverProfile == "full") {
    # kubernetes-mcp-server requires a host-local kubeconfig at ${kubeconfigFile};
    # omitted on minimal-profile hosts (e.g. headless servers) where no
    # cluster access is wired.
    kubernetes-mcp-server = {
      command = "${kubernetesMcpServer}/bin/kubernetes-mcp-server";
      args = [ "--read-only" ];
      env = {
        KUBECONFIG = kubeconfigFile;
      };
    };
    # Chrome DevTools for coding agents -- browser automation, debugging, screenshots.
    # Requires a Chrome install on the host; useless on headless. Also pulls
    # `chrome-devtools-mcp@latest` from npm at run time -- supply-chain surface
    # we do not want exposed on a server reachable via a token-authenticated web shell.
    chrome-devtools = {
      command = "${pkgs.nodejs}/bin/npx";
      args = [
        "-y"
        "chrome-devtools-mcp@latest"
      ];
    };
    # Playwright -- cross-browser automation (Chromium/Firefox/WebKit), accessibility
    # tree snapshots, network capture. Needs a browser engine; gated for the same
    # reasons as chrome-devtools above.
    playwright = {
      command = "${pkgs.nodejs}/bin/npx";
      args = [
        "-y"
        "@playwright/mcp@latest"
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
