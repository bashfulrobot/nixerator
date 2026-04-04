# Claudito Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a NixOS module that installs claudito (Claude Code agent dashboard) as a systemd user service, always available over LAN and Tailscale.

**Architecture:** `buildNpmPackage` derivation fetched from the npm registry (matching the clay pattern), wrapped with `makeWrapper`. Systemd user service exposes the web UI on port 3131 bound to all interfaces. Module options control port, host, credentials, max agents, and dev mode. Integrations (Slack, GitHub) are configured through claudito's own web UI — no secrets wiring needed.

**Tech Stack:** Nix (`buildNpmPackage`, `makeWrapper`), Home Manager (`systemd.user.services`), Node.js >= 20, node-pty (native binding requiring build tools)

**Important note on node-pty:** Claudito depends on `node-pty` which has native C++ bindings. The build derivation needs `python3` and `pkg-config` in `nativeBuildInputs`, and `libutil`/`libutempter` may be needed. If `buildNpmPackage` fails on native deps, fall back to a `stdenv.mkDerivation` with `fetchPnpmDeps` (sled pattern) or use `npmFlags = ["--ignore-scripts"]` and rebuild node-pty separately. The implementer should try the simple path first and adapt.

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `modules/server/claudito/default.nix` | Module definition: options, systemd service, package install |
| Create | `modules/server/claudito/build/default.nix` | `buildNpmPackage` derivation for claudito |
| Create | `modules/server/claudito/build/package-lock.json` | Lockfile for npm dependency resolution |
| Modify | `modules/suites/ai/default.nix` | Add `server.claudito.enable = true;` |
| Modify | `settings/versions.nix` | Add claudito version entry |

---

### Task 1: Add claudito to versions.nix

**Files:**
- Modify: `settings/versions.nix` (add entry in the `cli` section alongside clay)

- [ ] **Step 1: Find the current claudito version on npm**

Run:
```bash
npm view claudito version
```

Expected: A version string like `1.x.x`

- [ ] **Step 2: Fetch the tarball hash**

Run:
```bash
nix-prefetch-url "https://registry.npmjs.org/claudito/-/claudito-$(npm view claudito version).tgz"
```

Then convert to SRI:
```bash
nix hash convert --hash-algo sha256 --to sri <hash-from-above>
```

- [ ] **Step 3: Add the version entry to settings/versions.nix**

Add in the `cli` block (alphabetically, after `clay`):

```nix
    claudito = {
      source = "npm";
      repo = "comfortablynumb/claudito";
      npmPkg = "claudito";
      version = "<VERSION_FROM_STEP_1>";
      hash = "<SRI_HASH_FROM_STEP_2>";
      npmDepsHash = "";  # Will be filled in Task 2
    };
```

- [ ] **Step 4: Commit**

```bash
git add settings/versions.nix
git commit -m "feat(claudito): add version entry"
```

---

### Task 2: Create the build derivation

**Files:**
- Create: `modules/server/claudito/build/default.nix`
- Create: `modules/server/claudito/build/package-lock.json`

- [ ] **Step 1: Generate the package-lock.json**

Download the tarball and extract its package.json, then generate a lockfile:

```bash
mkdir -p /tmp/claudito-lock
cd /tmp/claudito-lock
npm pack claudito
tar xzf claudito-*.tgz
cd package
npm install --package-lock-only
cp package-lock.json /home/dustin/git/nixerator/modules/server/claudito/build/package-lock.json
cd /home/dustin/git/nixerator
rm -rf /tmp/claudito-lock
```

- [ ] **Step 2: Write the build derivation**

Create `modules/server/claudito/build/default.nix`:

```nix
{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
  python3,
  pkg-config,
  versions,
}:

buildNpmPackage rec {
  pname = "claudito";
  inherit (versions.cli.claudito) version npmDepsHash;

  npmDepsFetcherVersion = 2;

  src = fetchurl {
    url = "https://registry.npmjs.org/claudito/-/claudito-${version}.tgz";
    inherit (versions.cli.claudito) hash;
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  nativeBuildInputs = [ makeWrapper python3 pkg-config ];

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/node_modules/claudito"
    cp -r . "$out/lib/node_modules/claudito"

    mkdir -p "$out/bin"
    makeWrapper "${nodejs}/bin/node" "$out/bin/claudito" \
      --add-flags "$out/lib/node_modules/claudito/dist/cli.js" \
      --prefix PATH : "${nodejs}/bin"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Web-based dashboard for orchestrating multiple Claude Code agents";
    homepage = "https://github.com/comfortablynumb/claudito";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "claudito";
  };
}
```

**Note:** The `--add-flags` path (`dist/cli.js`) must be verified against the actual tarball contents. Check with:
```bash
tar tzf /tmp/claudito-lock/claudito-*.tgz | grep -E '(cli|bin|main)' | head -20
```
Also check `package.json` for the `"bin"` field to find the correct entry point.

- [ ] **Step 3: Compute the npmDepsHash**

Build with an empty hash to get the correct one:
```bash
cd /home/dustin/git/nixerator
nix build .#nixosConfigurations.donkeykong.config.system.build.toplevel 2>&1 | grep "got:"
```

Update `settings/versions.nix` with the correct `npmDepsHash`.

- [ ] **Step 4: Verify the build compiles**

```bash
nix build .#nixosConfigurations.donkeykong.config.system.build.toplevel
```

If node-pty fails, add to the derivation:
```nix
npmFlags = [ "--ignore-scripts" ];
npmRebuildFlags = [ "--ignore-scripts" ];
```
And handle native deps with `preInstall` or switch to the sled pattern (`stdenv.mkDerivation` + manual npm install).

- [ ] **Step 5: Commit**

```bash
git add modules/server/claudito/build/
git commit -m "feat(claudito): add buildNpmPackage derivation"
```

---

### Task 3: Create the module

**Files:**
- Create: `modules/server/claudito/default.nix`

- [ ] **Step 1: Write the module**

Create `modules/server/claudito/default.nix`:

```nix
{ lib, pkgs, config, globals, versions, ... }:

let
  cfg = config.server.claudito;
  claudito = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    server.claudito = {
      enable = lib.mkEnableOption "Claudito agent dashboard";

      port = lib.mkOption {
        type = lib.types.port;
        default = 3131;
        description = "Port for the claudito web server.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Host/interface to bind to.";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "dustin";
        description = "Username for claudito web auth.";
      };

      password = lib.mkOption {
        type = lib.types.str;
        default = "claudito";
        description = "Password for claudito web auth.";
      };

      maxAgents = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Maximum concurrent Claude agents.";
      };

      devMode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable experimental features (Git tab, etc).";
      };

      projectPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional project discovery paths (colon-separated in env).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [ claudito ];

      systemd.user.services.claudito = {
        Unit = {
          Description = "Claudito - Claude Code Agent Dashboard";
          After = [ "network.target" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${claudito}/bin/claudito";
          Restart = "on-failure";
          RestartSec = 10;
          Environment = [
            "PORT=${toString cfg.port}"
            "HOST=${cfg.host}"
            "CLAUDITO_USERNAME=${cfg.username}"
            "CLAUDITO_PASSWORD=${cfg.password}"
            "MAX_CONCURRENT_AGENTS=${toString cfg.maxAgents}"
          ]
          ++ lib.optional cfg.devMode "CLAUDITO_DEV_MODE=1"
          ++ lib.optional (cfg.projectPaths != [ ])
            "CLAUDITO_PROJECT_PATHS=${lib.concatStringsSep ":" cfg.projectPaths}";
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };
  };
}
```

- [ ] **Step 2: Verify the module parses**

```bash
nix-instantiate --parse modules/server/claudito/default.nix
```

Expected: Nix AST output, no errors.

- [ ] **Step 3: Commit**

```bash
git add modules/server/claudito/default.nix
git commit -m "feat(claudito): add server module with systemd user service"
```

---

### Task 4: Wire into the AI suite

**Files:**
- Modify: `modules/suites/ai/default.nix`

- [ ] **Step 1: Add claudito to the AI suite**

In `modules/suites/ai/default.nix`, add inside the `config = lib.mkIf cfg.enable { ... }` block, after `system.moshi.enable = true;`:

```nix
    server.claudito.enable = true;
```

- [ ] **Step 2: Verify full system build**

```bash
just quiet-rebuild
```

On failure, spawn a Nix subagent to read `/tmp/nixerator-rebuild.log`, diagnose, and fix.

- [ ] **Step 3: Verify the service is running**

```bash
systemctl --user status claudito
```

Expected: Active (running) or at least loaded.

- [ ] **Step 4: Test web access**

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3131
```

Expected: `401` (auth required) or `200`.

- [ ] **Step 5: Commit**

```bash
git add modules/suites/ai/default.nix
git commit -m "feat(ai): enable claudito in AI suite"
```

---

### Task 5: Open firewall for LAN/Tailscale access

**Files:**
- Modify: `modules/server/claudito/default.nix`

- [ ] **Step 1: Add firewall rule to the module**

In `modules/server/claudito/default.nix`, add to the `config = lib.mkIf cfg.enable { ... }` block (outside the `home-manager.users` block):

```nix
    networking.firewall.allowedTCPPorts = [ cfg.port ];
```

- [ ] **Step 2: Rebuild and verify**

```bash
just quiet-rebuild
```

- [ ] **Step 3: Test remote access from another device**

From a Tailscale-connected device, open `http://<host-tailscale-ip>:3131` in a browser. Should see claudito's login page.

- [ ] **Step 4: Commit**

```bash
git add modules/server/claudito/default.nix
git commit -m "feat(claudito): open firewall port for LAN/Tailscale access"
```
