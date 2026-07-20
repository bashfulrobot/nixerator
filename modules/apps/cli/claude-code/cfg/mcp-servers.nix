{
  lib,
  pkgs,
  secrets,
  kubernetesMcpServer,
  fluxOperatorMcp,
  isoTopologyPkg,
  kubeconfigFile,
  homeDir,
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
    # Grafana Cloud MCP -- hosted observability MCP (dashboards, metrics, logs,
    # alerts, incidents) for the bashfulrobot.grafana.net stack. Streamable-HTTP
    # endpoint; auth is OAuth 2.1 with browser authorization (no token in config,
    # same shape as atlassian/tactiq) -- run `/mcp` in Claude Code to complete the
    # flow. The X-Grafana-URL header pins the stack so authorization skips the
    # URL-entry step and goes straight to the consent page.
    grafana = {
      type = "http";
      url = "https://mcp.grafana.com/mcp";
      headers = {
        "X-Grafana-URL" = "https://bashfulrobot.grafana.net";
      };
    };
  }
  // lib.optionalAttrs (serverProfile == "full") {
    # iso-topology MCP server -- generate isometric 2.5D architecture diagrams
    # from a text DSL. Exposes capabilities, validate, evaluate, render, and
    # preview tools so agents can discover the DSL and produce design-grade SVGs
    # without any external service call. Workstation-only: headless hosts have
    # no use for SVG generation.
    #
    # Sandboxed with bubblewrap: read-only filesystem view (icon: DSL can read
    # local images but cannot write), network namespace isolated (no exfiltration
    # path even if the read path is exploited). The output_dir write path is
    # intentionally disabled in the sandbox; SVG content is returned inline in
    # MCP responses instead.
    iso-topology = {
      command = "${pkgs.bubblewrap}/bin/bwrap";
      args = [
        "--ro-bind"
        "/"
        "/"
        "--dev"
        "/dev"
        "--proc"
        "/proc"
        "--tmpfs"
        "/tmp"
        "--unshare-net"
        "--"
        "${isoTopologyPkg}/bin/isotopo-mcp"
      ];
    };
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
    # Flux Operator MCP server -- read-only, natural-language access to Flux CD
    # on whatever cluster the mcp-viewer kubeconfig points at (darkstar in the
    # homelab): trace a Kustomization/HelmRelease tree, read the FluxReport and
    # controller logs, compare environments. Same host-local kubeconfig gate as
    # kubernetes-mcp-server above (full profile only), so it is dropped on
    # headless hosts. --read-only forbids the reconcile/suspend/resume
    # mutations, and secrets are masked by default (--mask-secrets defaults on),
    # so Secret values never reach the model context.
    flux-operator-mcp = {
      command = "${fluxOperatorMcp}/bin/flux-operator-mcp";
      args = [
        "serve"
        "--read-only"
      ];
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
    # kongdex (https://github.com/KongHQ-CX/kongdex) -- local RAG over the Kong
    # developer docs (and optionally Kong source), exposed as a stdio MCP server.
    # Upstream names the server `kong-docs`; kept here so it reads parallel to the
    # `kong-konnect` live-API server (docs RAG vs Konnect control-plane API) and
    # matches the bundled kong-expert skill / kong-architect agent references.
    #
    # Runs from a local checkout, not a nixpkgs package: clone to
    # ${homeDir}/git/kongdex, then `uv sync` + `uv run kongdex refresh` to build
    # the Chroma index before the server has anything to serve. Until then (or if
    # the checkout is missing) the server just fails to connect in /mcp, same as
    # the npx-based servers above when their fetch fails.
    #
    # Workstation-only (serverProfile == "full"): the local index and embedder
    # have no place on a headless host, matching chrome-devtools/playwright/tableau.
    kong-docs = {
      command = "${pkgs.uv}/bin/uv";
      args = [
        "--directory"
        "${homeDir}/git/kongdex"
        "run"
        "kongdex"
        "serve"
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
  }
  // lib.optionalAttrs (serverProfile == "full" && (secrets.tableau.patValue or null) != null) {
    # Tableau MCP -- query/explore Tableau Cloud content (workbooks, views,
    # datasources) via natural language: https://github.com/tableau/tableau-mcp
    # Self-hosted/local (PAT-based) mode, not the hosted OAuth mcp.tableau.com
    # endpoint, matching the Claude Desktop setup already in use against
    # Kong's Tableau Cloud site. All four values (server, site, PAT name/value)
    # live on the "Tableau-PAT" 1Password item.
    #
    # Workstation-only, same as chrome-devtools/playwright above: `npx -y
    # @tableau/mcp-server` fetches and executes npm code at run time, and
    # secrets.json is pushed identically to every host, so without this gate
    # the entry would activate on the headless host (srv) the moment
    # the secret exists in the vault. Unlike those two, this server holds a
    # live Tableau Cloud credential in its process environment, so the
    # version is pinned rather than tracking @latest, to bound the blast
    # radius of a compromised npm release. Bump deliberately after checking
    # https://github.com/tableau/tableau-mcp/releases.
    #
    # ADMIN_TOOLS_ENABLED is intentionally left unset (defaults to false
    # upstream): it gates both the destructive tools (delete-workbook,
    # delete-datasource, etc.) and the whole Admin Insights read/query group
    # at tool registration time (see e.g. `disabled: !config.adminToolsEnabled`
    # in tableau-mcp's getStaleContentReport.ts), so none of that surface is
    # even exposed to the MCP client with this config.
    tableau = {
      command = "${pkgs.nodejs}/bin/npx";
      args = [
        "-y"
        "@tableau/mcp-server@2.22.0"
      ];
      env = {
        SERVER = secrets.tableau.server;
        SITE_NAME = secrets.tableau.siteName;
        PAT_NAME = secrets.tableau.patName;
        PAT_VALUE = secrets.tableau.patValue;
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

  # kong-konnect is the one server that must ALSO be registered at *user* scope
  # rather than only in the mcp-pick library below.
  #
  # Why: the kong-konnect@ai-marketplace plugin (modules/suites/ai) bundles its
  # own server, also called `kong-konnect`, whose `${KONNECT_TOKEN}` is never
  # set here. A plugin-provided server is active in every project, and Claude
  # Code offers no way to keep a plugin's skills while dropping its MCP servers.
  # Registering ours at user scope shadows the dead one everywhere, because
  # user scope outranks plugin scope; relying on mcp-pick alone would only
  # shadow it in projects that happen to have a .mcp.json.
  #
  # Only ~/.claude.json is read for user-scope `mcpServers`. The same key in
  # settings.json is silently ignored, so activation cannot take the usual
  # settings.json route. Verified against a throwaway `claude mcp add --scope
  # user`, which wrote to ~/.claude.json and left settings.json untouched.
  #
  # The PAT is deliberately NOT interpolated into this template: it is rendered
  # to the Nix store, which is world-readable. cfg/activation.nix substitutes
  # the real value at runtime straight out of the secrets file.
  userScopeTemplate = builtins.toJSON {
    mcpServers = lib.optionalAttrs (mcpServers ? kong-konnect) {
      kong-konnect = lib.recursiveUpdate mcpServers.kong-konnect {
        headers.Authorization = "Bearer @KONG_KONNECT_PAT@";
      };
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
  inherit mcpServers files userScopeTemplate;
}
