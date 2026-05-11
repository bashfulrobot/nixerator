# Hyperframes Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire Hyperframes (heygen-com/hyperframes) into the existing claude-code Nix module as a Claude Code plugin, gate its runtime deps (FFmpeg, system Chromium, Node.js 22, Puppeteer env vars) on plugin-list membership, enable it on workstations via `suites.ai`, and keep `srv` untouched.

**Architecture:** No new module. The change is additive inside `modules/apps/cli/claude-code/`: one new marketplace entry, one new installed-plugin entry, a single `hasHyperframes` boolean gate around three small package/env-var additions, plus one line in `modules/suites/ai/default.nix`. The srv host gets a comment-only edit explaining why hyperframes is not mirrored there.

**Tech Stack:** Nix, Home Manager, NixOS, JSON config fragments, just (justfile runner). Project conventions: `just qr` for rebuild, `just fmt` for formatting, `just health` for lint. No `git commit`/`git push` restriction applies here — the user has explicitly authorized autonomous merge for this run.

**Spec:** [`docs/plans/2026-05-10-hyperframes-module-design.md`](./2026-05-10-hyperframes-module-design.md). Read it for the design rationale.

---

### Task 1: Add `hyperframes` marketplace entry

**Files:**

- Modify: `modules/apps/cli/claude-code/config/plugins/known_marketplaces.json`

- [ ] **Step 1: Capture an ISO-8601 UTC timestamp to reuse in Task 2**

Run:

```bash
date -u +%FT%T.000Z
```

Expected: a single timestamp line, e.g. `2026-05-10T22:30:00.000Z`. **Note this value** — both Task 1 and Task 2 use it so the marketplace and plugin entries share a consistent install moment.

For the rest of this plan, the placeholder `<TS>` refers to that captured value.

- [ ] **Step 2: Append the marketplace entry**

Open `modules/apps/cli/claude-code/config/plugins/known_marketplaces.json`. The file currently ends with the `kong-se-skills` entry on line 41 followed by `}` on line 42. Insert a comma after the `kong-se-skills` entry's closing `}`, then add the `hyperframes` block before the file's final `}`:

```json
  "hyperframes": {
    "source": {
      "source": "github",
      "repo": "heygen-com/hyperframes"
    },
    "installLocation": "@HOME_DIR@/.claude/plugins/marketplaces/hyperframes",
    "lastUpdated": "<TS>"
  }
```

Final file shape (last ~12 lines):

```json
  "kong-se-skills": {
    "source": {
      "source": "git",
      "url": "https://github.com/KongHQ-SE/se-kong-skills.git"
    },
    "installLocation": "@HOME_DIR@/.claude/plugins/marketplaces/kong-se-skills",
    "lastUpdated": "2026-05-08T19:12:41.412Z"
  },
  "hyperframes": {
    "source": {
      "source": "github",
      "repo": "heygen-com/hyperframes"
    },
    "installLocation": "@HOME_DIR@/.claude/plugins/marketplaces/hyperframes",
    "lastUpdated": "<TS>"
  }
}
```

- [ ] **Step 3: Validate JSON**

Run:

```bash
jq . modules/apps/cli/claude-code/config/plugins/known_marketplaces.json > /dev/null
```

Expected: no output, exit 0. If JSON is malformed, jq prints the offending line and exits non-zero — fix and re-run.

- [ ] **Step 4: Confirm the new entry is present**

Run:

```bash
jq -r '.hyperframes.source.repo' modules/apps/cli/claude-code/config/plugins/known_marketplaces.json
```

Expected: `heygen-com/hyperframes`

---

### Task 2: Add `hyperframes@hyperframes` installed-plugin entry

**Files:**

- Modify: `modules/apps/cli/claude-code/config/plugins/installed_plugins.json`

The plugin entry stub matches the `pyright-lsp` shape (no `gitCommitSha` — that field is optional and Claude Code populates it on first sync).

- [ ] **Step 1: Append the plugin entry**

Open `modules/apps/cli/claude-code/config/plugins/installed_plugins.json`. The file's top-level is `{ "version": 2, "plugins": { … } }`. Inside `.plugins`, after the existing last entry (`feature-request@kong-cs`), insert a comma on the preceding `]` line and add:

```json
    "hyperframes@hyperframes": [
      {
        "scope": "user",
        "installPath": "@HOME_DIR@/.claude/plugins/cache/hyperframes/hyperframes/0.1.0",
        "version": "0.1.0",
        "installedAt": "<TS>",
        "lastUpdated": "<TS>"
      }
    ]
```

Use the same `<TS>` value captured in Task 1, Step 1.

`version` is `0.1.0` per the upstream `.claude-plugin/plugin.json` at design time.

- [ ] **Step 2: Validate JSON**

Run:

```bash
jq . modules/apps/cli/claude-code/config/plugins/installed_plugins.json > /dev/null
```

Expected: no output, exit 0.

- [ ] **Step 3: Confirm the new entry is keyed correctly**

Run:

```bash
jq -r '.plugins | keys[] | select(. == "hyperframes@hyperframes")' modules/apps/cli/claude-code/config/plugins/installed_plugins.json
```

Expected: `hyperframes@hyperframes`

- [ ] **Step 4: Commit the JSON additions**

```bash
git add modules/apps/cli/claude-code/config/plugins/known_marketplaces.json modules/apps/cli/claude-code/config/plugins/installed_plugins.json
git commit -m "feat(claude-code): register hyperframes marketplace + plugin"
```

---

### Task 3: Add `hasHyperframes` gate to claude-code module

**Files:**

- Modify: `modules/apps/cli/claude-code/default.nix`

The current `let` block (lines 12-66) ends at line 65 (`configDir = ./config;`). Add the new binding after `configDir` and before the closing `in`.

- [ ] **Step 1: Add the `hasHyperframes` binding**

Edit `modules/apps/cli/claude-code/default.nix`. After this existing line near the end of the `let` block:

```nix
  # Path to config directory (Nix store copy for activation script)
  configDir = ./config;
```

Insert immediately after (still inside the `let` block, before `in`):

```nix

  # Hyperframes plugin requires ffmpeg + chromium + node + puppeteer env vars
  # on the host. Gate the runtime deps on plugin-list membership so the
  # closure is unchanged on hosts where the plugin isn't enabled.
  hasHyperframes = lib.elem "hyperframes@hyperframes" cfg.plugins;
```

- [ ] **Step 2: Confirm the binding parses**

Run:

```bash
nix-instantiate --parse modules/apps/cli/claude-code/default.nix > /dev/null
```

Expected: no output, exit 0. If parsing fails, nix-instantiate prints a syntax error — fix it.

---

### Task 4: Wire `ffmpeg-full` + `chromium` into `environment.systemPackages`

**Files:**

- Modify: `modules/apps/cli/claude-code/default.nix`

The existing block at lines 101-125 builds `environment.systemPackages` from a `with pkgs;` list plus a conditional `lib.optionals (cfg.serverProfile == "full")` block. The `hyperframes` conditional adds another `lib.optionals` block, parallel to the existing one.

- [ ] **Step 1: Extend `environment.systemPackages`**

Find this block in `default.nix` (currently lines 101-125):

```nix
    environment.systemPackages =
      (with pkgs; [
        (writeScriptBin "mcp-pick" mcpPick)
        llm-agents.claude-plugins # Plugin & skills manager
        fzf
        jq
        rsync # used by claude-capture + activation to mirror skills

        # Language servers for Claude Code LSP integration
        bash-language-server
        dart
        gopls
        lua-language-server
        pyright
        rust-analyzer
        terraform-ls
        vtsls
        yaml-language-server
      ])
      ++ lib.optionals (cfg.serverProfile == "full") [
        # k8s-mcp-setup is the operator script that wires kubernetes-mcp-server
        # against a host-local kubeconfig. Pointless on minimal-profile hosts
        # where the kubernetes MCP server itself is gated out.
        (pkgs.writeScriptBin "k8s-mcp-setup" k8s-mcp-setup)
      ];
```

Add a third concatenated list after the `serverProfile == "full"` block, before the trailing `;`:

```nix
      ++ lib.optionals hasHyperframes [
        # Hyperframes plugin invokes `npx hyperframes` which spawns ffmpeg
        # for rendering and a system chromium via puppeteer for HTML capture.
        # Puppeteer's bundled chromium binary does not run on NixOS, so the
        # system chromium becomes the puppeteer target via env vars below.
        pkgs.ffmpeg-full
        pkgs.chromium
      ];
```

Resulting shape (last ~10 lines of the assignment):

```nix
      ++ lib.optionals (cfg.serverProfile == "full") [
        (pkgs.writeScriptBin "k8s-mcp-setup" k8s-mcp-setup)
      ]
      ++ lib.optionals hasHyperframes [
        pkgs.ffmpeg-full
        pkgs.chromium
      ];
```

Note: the `;` moves from after `]` of the serverProfile block to after `]` of the hyperframes block.

- [ ] **Step 2: Confirm parses**

Run:

```bash
nix-instantiate --parse modules/apps/cli/claude-code/default.nix > /dev/null
```

Expected: no output, exit 0.

---

### Task 5: Wire `PUPPETEER_*` env vars into both system and home

**Files:**

- Modify: `modules/apps/cli/claude-code/default.nix`

The existing `GEMINI_API_KEY` plumbing at lines 128-130 (system) and 136-138 (home) is the pattern. Replicate it with the hyperframes condition.

- [ ] **Step 1: Extend `environment.variables`**

Find this block (currently lines 127-130):

```nix
    # Gemini API key for generate-images / visual-explainer skills
    environment.variables = lib.optionalAttrs (secrets ? gemini && secrets.gemini ? apiKey) {
      GEMINI_API_KEY = secrets.gemini.apiKey;
    };
```

Replace the `environment.variables =` assignment with this version that merges in the puppeteer attrs:

```nix
    # Gemini API key for generate-images / visual-explainer skills
    # Puppeteer env vars only applied when hyperframes plugin is enabled — keeps
    # the system environment clean on hosts that don't use it.
    environment.variables =
      lib.optionalAttrs (secrets ? gemini && secrets.gemini ? apiKey) {
        GEMINI_API_KEY = secrets.gemini.apiKey;
      }
      // lib.optionalAttrs hasHyperframes {
        PUPPETEER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
        PUPPETEER_SKIP_DOWNLOAD = "1";
      };
```

- [ ] **Step 2: Extend `home.sessionVariables`**

Find this block inside `home-manager.users.${globals.user.name}` (currently lines 136-138):

```nix
        sessionVariables = lib.optionalAttrs (secrets ? gemini && secrets.gemini ? apiKey) {
          GEMINI_API_KEY = secrets.gemini.apiKey;
        };
```

Replace with:

```nix
        sessionVariables =
          lib.optionalAttrs (secrets ? gemini && secrets.gemini ? apiKey) {
            GEMINI_API_KEY = secrets.gemini.apiKey;
          }
          // lib.optionalAttrs hasHyperframes {
            PUPPETEER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
            PUPPETEER_SKIP_DOWNLOAD = "1";
          };
```

- [ ] **Step 3: Confirm parses**

Run:

```bash
nix-instantiate --parse modules/apps/cli/claude-code/default.nix > /dev/null
```

Expected: no output, exit 0.

---

### Task 6: Wire `nodejs_22` into the user packages

**Files:**

- Modify: `modules/apps/cli/claude-code/default.nix`

The existing user-packages assignment at lines 139-151 concatenates a `with pkgs;` list with an optional list gated on `serverProfile == "full"` and then with `pluginsConfig.packages ++ reapConfig.packages`. Add a new `lib.optionals hasHyperframes` segment.

- [ ] **Step 1: Extend `home.packages`**

Find this block (currently lines 139-151):

```nix
        packages =
          (with pkgs; [
            llm-agents.claude-code
          ])
          ++ lib.optionals (cfg.serverProfile == "full") (
            with pkgs;
            [
              libnotify # for notify-send in Stop hook (workstation-only)
              libreoffice # soffice on PATH -- required for marp-slides skill's --pptx-editable export (workstation-only)
            ]
          )
          ++ pluginsConfig.packages
          ++ reapConfig.packages;
```

Add a fourth `++` concatenation before the trailing `;`:

```nix
        packages =
          (with pkgs; [
            llm-agents.claude-code
          ])
          ++ lib.optionals (cfg.serverProfile == "full") (
            with pkgs;
            [
              libnotify # for notify-send in Stop hook (workstation-only)
              libreoffice # soffice on PATH -- required for marp-slides skill's --pptx-editable export (workstation-only)
            ]
          )
          ++ lib.optionals hasHyperframes [
            # Claude Code bundles node internally, but `npx hyperframes` must
            # dispatch to a user-visible Node >= 22. Pinning nodejs_22 matches
            # the version already used by skillfish and dorkos build derivations.
            pkgs.nodejs_22
          ]
          ++ pluginsConfig.packages
          ++ reapConfig.packages;
```

- [ ] **Step 2: Confirm parses**

Run:

```bash
nix-instantiate --parse modules/apps/cli/claude-code/default.nix > /dev/null
```

Expected: no output, exit 0.

- [ ] **Step 3: Commit the module changes**

```bash
git add modules/apps/cli/claude-code/default.nix
git commit -m "feat(claude-code): gate hyperframes runtime deps on plugin membership"
```

---

### Task 7: Enable `hyperframes@hyperframes` in the AI suite

**Files:**

- Modify: `modules/suites/ai/default.nix`

- [ ] **Step 1: Append the plugin ID to the suite's plugin list**

Find the plugin list in `modules/suites/ai/default.nix` (currently lines 31-47). The last entry is `"ralph-loop@claude-plugins-official"` on line 46. Add `"hyperframes@hyperframes"` on a new line after it:

```nix
      claude-code = {
        enable = true;
        plugins = [
          "frontend-design@claude-plugins-official"
          "asana@claude-plugins-official"
          "code-review@claude-plugins-official"
          "context7@claude-plugins-official"
          "github@claude-plugins-official"
          "feature-dev@claude-plugins-official"
          "commit-commands@claude-plugins-official"
          "security-guidance@claude-plugins-official"
          "pr-review-toolkit@claude-plugins-official"
          "atlassian@claude-plugins-official"
          "learning-output-style@claude-plugins-official"
          "slack@claude-plugins-official"
          "gopls-lsp@claude-plugins-official"
          "skill-creator@claude-plugins-official"
          "ralph-loop@claude-plugins-official"
          "hyperframes@hyperframes"
        ];
      };
```

- [ ] **Step 2: Confirm parses**

Run:

```bash
nix-instantiate --parse modules/suites/ai/default.nix > /dev/null
```

Expected: no output, exit 0.

---

### Task 8: Update srv's "keep in sync" comment

**Files:**

- Modify: `hosts/srv/modules.nix`

- [ ] **Step 1: Update the comment at lines 48-50**

Find this comment block (currently lines 48-50):

```nix
      # NOTE: keep plugin list in sync with modules/suites/ai/default.nix.
      # Two occurrences = below the rule-of-three threshold; do not
      # extract into shared lib until a third consumer appears.
```

Replace with:

```nix
      # NOTE: keep plugin list in sync with modules/suites/ai/default.nix,
      # EXCEPT "hyperframes@hyperframes" — workstation-only because it pulls
      # in ffmpeg + chromium + node, and srv is headless. Two occurrences =
      # below the rule-of-three threshold; do not extract into shared lib
      # until a third consumer appears.
```

Leave the plugin list itself unchanged — `"hyperframes@hyperframes"` is intentionally NOT added to srv.

- [ ] **Step 2: Confirm parses**

Run:

```bash
nix-instantiate --parse hosts/srv/modules.nix > /dev/null
```

Expected: no output, exit 0.

- [ ] **Step 3: Commit the activation changes**

```bash
git add modules/suites/ai/default.nix hosts/srv/modules.nix
git commit -m "feat(suites/ai): enable hyperframes plugin on workstations"
```

---

### Task 9: Format and lint

**Files:**

- Any: may rewrite formatting in any `.nix` file touched above.

- [ ] **Step 1: Format**

Run:

```bash
just fmt
```

Expected: silent success, possibly small whitespace diffs in files we just edited.

- [ ] **Step 2: Lint**

Run:

```bash
just health
```

Expected: `deadnix` and `statix` report no issues for the files we changed. If a pre-existing issue elsewhere appears, ignore it — scope is the four files this PR touches.

- [ ] **Step 3: Commit any formatting changes**

If `just fmt` produced diffs:

```bash
git add -u modules/ hosts/
git commit -m "style: nix fmt after hyperframes integration"
```

If `git status` is clean, skip the commit.

---

### Task 10: Rebuild the host

**Files:** None modified. This step is a verification gate.

- [ ] **Step 1: Run a quiet rebuild**

Run:

```bash
just qr
```

Expected: success. Output is captured to `/tmp/nixerator-rebuild.log`.

On failure (`just qr` exits non-zero):

1. Do NOT read `/tmp/nixerator-rebuild.log` in the main context — it's noisy.
2. Dispatch the `nix` subagent with this prompt:

   > Read `/tmp/nixerator-rebuild.log`. The rebuild ran on branch `feat/49-hyperframes-module` against issue #49 (hyperframes integration). Recent changes:
   > - Added `hyperframes` marketplace + `hyperframes@hyperframes` plugin entries to `modules/apps/cli/claude-code/config/plugins/*.json`.
   > - Added `hasHyperframes = lib.elem "hyperframes@hyperframes" cfg.plugins;` gate in `modules/apps/cli/claude-code/default.nix`.
   > - Conditionally added `pkgs.ffmpeg-full`, `pkgs.chromium` to `environment.systemPackages`; `PUPPETEER_*` env vars to `environment.variables` and `home.sessionVariables`; `pkgs.nodejs_22` to user `home.packages`.
   > - Added `"hyperframes@hyperframes"` to `modules/suites/ai/default.nix`.
   >
   > Identify the root-cause error and propose a minimal fix.

   Apply the fix, re-run `just qr`, repeat at most once. If a second rebuild fails, escalate — do not loop indefinitely.

- [ ] **Step 2: Verify ffmpeg + chromium + node on PATH**

Run:

```bash
command -v ffmpeg && ffmpeg -version | head -1
command -v chromium && chromium --version
command -v node && node --version
```

Expected:

- `ffmpeg version` (specific version varies by nixpkgs pin)
- `Chromium <version>`
- `v22.x.x` (any 22.x patch)

- [ ] **Step 3: Verify PUPPETEER env vars are set**

Run:

```bash
echo "PUPPETEER_EXECUTABLE_PATH=$PUPPETEER_EXECUTABLE_PATH"
echo "PUPPETEER_SKIP_DOWNLOAD=$PUPPETEER_SKIP_DOWNLOAD"
```

Expected:

- `PUPPETEER_EXECUTABLE_PATH=/nix/store/<hash>-chromium-<version>/bin/chromium`
- `PUPPETEER_SKIP_DOWNLOAD=1`

If either is empty: the shell may need to be re-sourced after rebuild. Open a new shell and re-check. If still empty, treat as a failed rebuild and dispatch the nix subagent.

- [ ] **Step 4: Verify the plugin entries deployed**

Run:

```bash
jq -r '.hyperframes' ~/.claude/plugins/known_marketplaces.json
jq -r '.plugins["hyperframes@hyperframes"]' ~/.claude/plugins/installed_plugins.json
```

Expected: both return non-null objects matching what we authored.

- [ ] **Step 5: Smoke-test the Hyperframes CLI**

Run:

```bash
npx -y hyperframes --version
```

Expected: a version string is printed. (First run downloads the package — may take 30-60s.)

If npx fails because the registry is unreachable, this is an environment issue, not a code issue — verify connectivity and retry; do not treat as plan failure.

---

### Self-review

After completing all tasks, before transitioning out of `implement`:

- [ ] All four target files modified: `known_marketplaces.json`, `installed_plugins.json`, `claude-code/default.nix`, `suites/ai/default.nix`. One additional file (`hosts/srv/modules.nix`) had a comment-only edit.
- [ ] `git log --oneline feat/49-hyperframes-module ^origin/main` shows the expected commits.
- [ ] `just qr` succeeded.
- [ ] All five verification commands in Task 10 returned the expected output.
- [ ] No edits made to files outside the planned scope (run `git diff --stat origin/main..HEAD` and check the file list matches the plan).

Once self-review passes, the github-issue skill handles the rest: `transition implement → verify → push`, then `/review-dev` and `/review-security`, then `github-issue auto-merge 49`, then wait for merge and run `github-issue cleanup 49`.
