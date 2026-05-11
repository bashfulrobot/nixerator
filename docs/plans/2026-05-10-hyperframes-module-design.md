# Hyperframes integration — design

Issue: [#49](https://github.com/bashfulrobot/nixerator/issues/49) — "Hyperframes module".

Branch: `feat/49-hyperframes-module`.

## Background

[Hyperframes](https://github.com/heygen-com/hyperframes) (HeyGen) is a TypeScript framework that renders HTML compositions to video using Puppeteer + FFmpeg. It ships as:

- An npm CLI (`npx hyperframes …`).
- A self-contained Claude Code marketplace (`heygen-com/hyperframes`) exposing a single plugin (`hyperframes@hyperframes`). The plugin bundles a set of skills: `hyperframes-cli`, `gsap`, `lottie`, `animejs`, `waapi`, `tailwind`, `three`, `website-to-hyperframes`, `hyperframes-media`, `hyperframes-registry`, `contribute-catalog`, `remotion-to-hyperframes`, `css-animations`.
- No MCP server, no commands, no hooks (verified against the upstream `.claude-plugin/plugin.json`).

Runtime requirements (upstream README): Node.js ≥ 22, FFmpeg, and — implicitly because Puppeteer is the capture engine — a Chromium-family browser that runs on NixOS. Puppeteer's bundled Chromium binary does not run on NixOS, so `PUPPETEER_EXECUTABLE_PATH` must point at the user's preferred browser binary and `PUPPETEER_SKIP_DOWNLOAD=1` must be set.

The integration intentionally does NOT install a browser package itself. The user's preferred Chromium-family browser is declared by `globals.preferences.browser` (e.g., `"google-chrome-stable"`) and provisioned by the appropriate browser module (today `apps.gui.google-chrome` via `suites.browsers`). The hyperframes runtime-dep gate resolves `PUPPETEER_EXECUTABLE_PATH` through `/run/current-system/sw/bin/${globals.preferences.browser}` so a future switch (e.g. to `chromium`, `brave-browser`, or `vivaldi-stable`) requires only a `globals.preferences.browser` flip plus enabling the relevant browser module — no edit to this module.

Upstream version at design time: `v0.5.7` (2026-05-10).

## Goals

1. Add Hyperframes to the AI suite as a Claude Code plugin so its skills are available in Claude Code sessions.
2. Provide the runtime dependencies it actually needs (FFmpeg, Node.js 22, Puppeteer env vars). The Chromium-family browser binary itself is **not** installed by this gate — it's resolved from `globals.preferences.browser` and is expected to already be provisioned by the user's browser module of choice (`suites.browsers` on workstations).
3. Workstations only — any host enabling the `workstation` archetype (currently `donkeykong` and `qbert`, but the gate is `archetypes.workstation`, not a hardcoded host list). Do not impose the runtime closure on the headless `srv` host or any future server-archetype host.
4. Keep the change small. No new module directory. No new `apps.cli.*` option. Existing claude-code plugin pattern carries it.

## Non-goals

- Wrapping Hyperframes as a `pkgs.callPackage`-style derivation. `npx hyperframes` is the upstream-supported install path; pinning a derivation would mean tracking npm transitive deps.
- Generalised "per-plugin runtime deps" abstraction. One plugin needs runtime deps today. Two would still be below the rule-of-three line called out in `hosts/srv/modules.nix:48-50`. Revisit if a third surfaces.
- Standalone `modules/apps/cli/hyperframes/` module. Claude Code plugin installation is centralised in `claude-code/config/plugins/`; a separate module would either (a) duplicate that wiring or (b) reach into the claude-code module's files, which is the "code circus" path the issue explicitly rules out.
- Enabling on `srv`. `srv` cherry-picks claude-code in `hosts/srv/modules.nix` and explicitly maintains its own plugin list. Hyperframes is workstation-only by scope decision.

## Approach

Fold into the existing `apps.cli.claude-code` module. Hyperframes ships as a Claude Code plugin upstream; the module already manages 23 plugins through the same mechanism. The marginal cost is one marketplace entry, one plugin entry, one suite-list entry, and ~12 lines of conditional runtime-dep wiring.

## Detailed design

### File touches

| File | Change |
|---|---|
| `modules/apps/cli/claude-code/config/plugins/known_marketplaces.json` | Add `hyperframes` marketplace entry. Shape mirrors existing `kong-cs` / `claude-plugins-official` entries: `source.source = "github"`, `source.repo = "heygen-com/hyperframes"`, `installLocation = "@HOME_DIR@/.claude/plugins/marketplaces/hyperframes"`, `lastUpdated` = ISO-8601 string captured at authoring time. |
| `modules/apps/cli/claude-code/config/plugins/installed_plugins.json` | Add `hyperframes@hyperframes` key under `.plugins`. Synthetic stub with `scope = "user"`, `installPath = "@HOME_DIR@/.claude/plugins/cache/hyperframes/hyperframes/unknown"`, `version = "unknown"`, `installedAt` + `lastUpdated` = capture timestamp. `gitCommitSha` omitted (the `pyright-lsp` entry shows this field is optional). Claude Code refreshes these fields on first plugin sync. |
| `modules/apps/cli/claude-code/default.nix` | (1) Add `hasHyperframes = lib.elem "hyperframes@hyperframes" cfg.plugins;` in the `let` block. (2) Conditionally extend `environment.systemPackages` with `[ pkgs.ffmpeg-full pkgs.chromium ]`. (3) Conditionally extend **both** `environment.variables` and `home-manager.users.${globals.user.name}.home.sessionVariables` with `{ PUPPETEER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium"; PUPPETEER_SKIP_DOWNLOAD = "1"; }` — mirroring the existing `GEMINI_API_KEY` pattern at `default.nix:128` and `default.nix:136-138`. (4) Conditionally extend `home-manager.users.${globals.user.name}.home.packages` with `[ pkgs.nodejs_22 ]`. |
| `modules/suites/ai/default.nix` | Append `"hyperframes@hyperframes"` to `apps.cli.claude-code.plugins`. |
| `hosts/srv/modules.nix` | No code change. Update the comment at line 48 ("keep plugin list in sync with modules/suites/ai/default.nix") to note that `hyperframes@hyperframes` is intentionally workstation-only and not mirrored on srv. |

### Runtime-dep gating

A single boolean (`hasHyperframes`) drives three additive deltas inside the existing `config = lib.mkIf cfg.enable { … }` block. The condition is `lib.elem` against `cfg.plugins`, not a new option — the source of truth stays the plugin list.

- **System packages**: `pkgs.ffmpeg-full` only (broad codec coverage; matches what npm-installed render pipelines tend to expect). No browser package — see Goal #2 above.
- **Environment variables**: `PUPPETEER_EXECUTABLE_PATH = "/run/current-system/sw/bin/${globals.preferences.browser}"` (computed once in the module's `let` as `hyperframesBrowserPath`) and `PUPPETEER_SKIP_DOWNLOAD = "1"`. Set in both `environment.variables` and `home.sessionVariables` so they're visible to system-level shells *and* the user's interactive sessions where `npx hyperframes` actually runs. The global scope is deliberate under the project's single-user threat model (workstation, git-crypt secrets, no untrusted local accounts): the env vars also propagate to any unrelated `npx`/`npm` invocations on the box, but a compromised npm dep can already spawn the user's browser directly — pointing it at the system binary via `PUPPETEER_EXECUTABLE_PATH` doesn't widen what an attacker who already has user-shell execution can do. If the threat model ever changes (multi-user host, untrusted projects), wrap `npx hyperframes` in a `pkgs.writeShellApplication` and drop the global env vars.
- **User packages**: `pkgs.nodejs_22`. Claude Code itself bundles Node internally, but `npx hyperframes` must dispatch to a user-visible Node ≥ 22. Pinning `nodejs_22` matches the version already used by `modules/apps/cli/skillfish/build/default.nix` and `modules/apps/cli/dorkos/build/default.nix`, avoiding multi-major-Node drift on workstations.

Closure delta is zero on hosts where the plugin is not declared (srv).

### Why not a separate `apps.cli.claude-code.hyperframes.enable` option

Two reasons:

1. The plugins list is already the declarative surface for "what Claude Code plugins are turned on." Adding a second knob splits that surface.
2. The runtime deps exist specifically because the plugin will be used. Coupling them to plugin-list membership (`lib.elem`) keeps the contract one-directional: declare the plugin, the deps follow.

If two more plugins ever need runtime deps, this graduates to a `pluginRuntimeDeps` attrset under the existing option. Not now.

### Activation flow

1. Rebuild → flake eval, `claude-code` module places marketplace + plugin JSON into `~/.claude/plugins/`, runtime deps land on `$PATH` and in environment.
2. `claude-sync-plugins` (existing helper, `cfg/plugins.nix`) reads `desired_plugins` (from Nix) vs `installed_plugins.json` (on disk). Both contain `hyperframes@hyperframes`, so it no-ops.
3. Claude Code on first launch materialises the plugin cache under `~/.claude/plugins/cache/hyperframes/hyperframes/` by cloning from the marketplace source — same path every other plugin takes.
4. Plugin's bundled skills auto-load into Claude Code's skill registry.

### Failure modes and mitigations

| Risk | Mitigation |
|---|---|
| `claude-sync-plugins` does not recognise the synthetic stub and tries to reinstall | Idempotent — `claude-plugins install` is `pipe "y"`-ed; re-install is a no-op if already cached. Worst case: a write to `installed_plugins.json` on first activation. |
| Puppeteer's bundled chromium still gets invoked (env var ignored) | `PUPPETEER_SKIP_DOWNLOAD=1` + `PUPPETEER_EXECUTABLE_PATH` is the upstream-documented escape hatch. Verified against [puppeteer config docs](https://pptr.dev/guides/configuration). |
| `globals.preferences.browser` names a binary that isn't installed | `PUPPETEER_EXECUTABLE_PATH` points at a non-existent `/run/current-system/sw/bin/...` entry; puppeteer launch fails at first frame with a clear error. The fix is one of: enable the browser module, or change `globals.preferences.browser` to a binary that is installed. Failure is loud, not silent. |
| User picks a non-Chromium browser (Firefox) in `globals.preferences.browser` | Puppeteer cannot drive Firefox via this env var (would need `puppeteer-firefox`, deprecated). Failure surfaces at first `puppeteer.launch()` — runtime, not eval-time. Document the "Chromium-family" expectation; this PR does not enforce it in Nix. |
| `ffmpeg-full` is a larger closure than needed | Acceptable. Hyperframes documents `ffmpeg` as a hard requirement and gives no codec subset. `ffmpeg-full` avoids "missing codec at render time" debugging. |
| Hyperframes upstream changes its marketplace name or repo path | Localised to one entry in `known_marketplaces.json` + one ID in two plugin lists. No re-architecting. |
| User invokes plugin on a host without ffmpeg (e.g., enables plugin manually outside suites.ai) | The gate is `lib.elem` on `cfg.plugins`; if the plugin is declared anywhere in `cfg.plugins`, the deps appear. Direct mismatch would require declaring the plugin without going through the module, which the architecture prevents. |

### Verification (post-design, in the implement step)

- `just build` against a workstation host (donkeykong) — flake evaluates.
- `nix flake check` — schema valid.
- After deploy on donkeykong:
  - `claude-plugins list | rg hyperframes` → entry present.
  - `command -v ffmpeg && ffmpeg -version | head -1` → ffmpeg-full on PATH.
  - `command -v chromium && chromium --version` → chromium on PATH.
  - `env | rg PUPPETEER` → both env vars set.
  - `command -v node && node --version` → ≥ v22.
  - `npx -y hyperframes --version` → CLI runs.
- Spot-check one bundled skill — e.g., open Claude Code, confirm a hyperframes skill is discoverable via `/skill` or appears in the auto-loaded skill list. (Not a hard pass/fail gate; rendering exercises happen in real use.)
- On srv (after rebuild): `claude-plugins list | rg hyperframes` → absent. No FFmpeg, no Chromium pulled in. Closure size unchanged.

## Out of scope

- A Hyperframes derivation in `pkgs/`. Upstream supports `npx`; we follow that.
- Pinning Hyperframes to a specific version. The marketplace tracks upstream `main` (same as every other plugin). If pinning becomes necessary, add a `gitCommitSha` to the plugin entry — single-line change.
- Wiring Hyperframes into Claude Remote, Gemini CLI, or any other agent on the box. Out of scope per the issue body.
- Rendering inside CI / container builds. The puppeteer + ffmpeg pipeline is workstation interactive.

## Open questions

None. All design choices grounded in current file state.

## References

- Upstream marketplace manifest: <https://raw.githubusercontent.com/heygen-com/hyperframes/main/.claude-plugin/marketplace.json>
- Upstream plugin manifest: <https://raw.githubusercontent.com/heygen-com/hyperframes/main/.claude-plugin/plugin.json>
- Existing plugin-install pattern: `modules/apps/cli/claude-code/default.nix:34-37, 220-252` and `cfg/plugins.nix`.
- srv plugin-list sync rule: `hosts/srv/modules.nix:48-50` ("keep plugin list in sync … below the rule-of-three threshold").
- Workstation archetype enabling suites.ai: `modules/archetypes/workstation/default.nix:34-45`.
