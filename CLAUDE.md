# Nixerator

Personal NixOS / home-manager flake covering Dustin's hosts (`qbert`, `srv`). Module-based config, justfile-driven rebuilds, secrets via 1Password (`op inject`; git-crypt retired), claude-code stack auto-imported.

See `~/.claude/CLAUDE.md` for the global *thin-CLAUDE.md protocol* and *Where curated knowledge goes* rubric. Project topic files live in `.claude/docs/`.

## Assistant output

Rules for how you talk to Dustin on screen — separate from `/dk:text-polish`,
which governs prose sent elsewhere (Slack, email, docs):

- Tag confidence on technical or factual claims: `[Certain]` (verified/hard
  evidence), `[Likely]` (strong inference), `[Guessing]` (filling a gap).
  Skip the tag on trivial or already-verified statements.
- Never open a reply with "Great question", "You're absolutely right",
  "That makes a lot of sense", "Absolutely", or "Definitely".
- If there's a caveat, risk, or piece of bad news, lead with it — don't
  bury it after the good news.
- No warm-up paragraphs ("There are several ways to look at this..."). Start
  with the most useful sentence.
- If Dustin pushes back, hold your position unless he gives genuinely new
  information — repeated disagreement without new facts isn't a reason to
  fold.

## Topics

- When making code changes — builds, rebuilds, lint, format, upgrades, git discipline, secrets — read `.claude/docs/conventions.md`.
- When adding or modifying a browser-wrapped web app under `modules/apps/webapps/`, read `.claude/docs/webapps.md` — `wmClass` must be verified with `lswt` after rebuild.
- When you need to look up docs for a Nix tool, library, or flake input, read `.claude/docs/sources.md` (gitmcp lookup table).
- When you need a local CLI tool (`amber`, `cpx`, `meetsum`, `nix-init`, `ballpoint`), read `.claude/docs/tools.md`.
- When the user asks about cross-device session pickup, the `work` fish function, the `claudeWorkHost` archetype, or how to attach to a session from the iPhone, read `.claude/docs/cross-device-workflow.md`.
- **Secrets (hard rule):** NEVER read rendered secret values — not from `~/.config/nixos-secrets/secrets.json` and not from 1Password (`op read`/`op item get --reveal`), not even a prefix or length. Item titles, field labels, `op://` paths, and placeholders are fine. For the full 1Password flow — adding, rotating, per-host setup, the vault item table — read `extras/docs/secrets.md`.
- When a skill repeatedly resolves names→IDs or re-queries an external API for the same data, read `.claude/docs/skill-cache.md` for the warm-cache convention and the `skill-cache` CLI.
- When capturing DankMaterialShell (DMS) GUI settings back into Nix, or touching the dank capture/seed flow (`dank-capture`/`dank-diff`/`dank-discard`, `just capture`, `dank-profiles/`), read `.claude/docs/dank-capture.md`.
- When working with Claude Code plugins (the declarative marketplace/enabled surface in `cfg/plugin-config.nix`, `installed_plugins.json` capture behavior, or Kong Konnect skills showing installed but missing), read `.claude/docs/claude-plugins.md`.
- When touching `systemd.user` timers, `users.users.<name>.linger`, or a unit that assumes a graphical session, read `.claude/docs/user-lingering.md` — `Linger=yes` on a running host is not evidence the declaration exists.
- When adding, bumping, or debugging a skill vendored from a flake input (`humanizer`, `intent-layer`, `walkr-author`, `walkr-tutorial-author`, or the seven VibeCurb design skills), read `.claude/docs/vendored-skills.md`.
- When touching `server.nanoclaw` on srv (NanoClaw + OneCLI vault, its agenix-only secrets, the setup-token re-auth flow), read `extras/docs/nanoclaw/README.md`.
- When adding a skill, changing the always-on baseline, or debugging why a skill is missing/present in a project, read `.claude/docs/skill-defaults.md` for the default-off model and `skill-pick`.

## Reference docs

For a one-scroll visual overview — file map, module anatomy, the rebuild pipeline, the two hosts, secrets flow — open `extras/docs/index.html` (`just docs`). When building or editing that page, read `extras/docs/CLAUDE.md`.

For deep-dive topics — directory structure, hosts, adding hosts, modules, packages, secrets, SSH, GPU, hyprland, VM dev, bootstrap — browse `extras/docs/` (one `.md` per topic). Start with `extras/docs/architecture.md` for the layout map.

## TODO

Open items from the claude-stack consolidation (Oct 2026). None of the Nix
edits were evaluated on macOS, so the first rebuild on each host is the real
test. Tick an item off in the same commit that finishes it.

- [x] **1Password service account:** fixed by Dustin on 2026-10-13 (`just render-secrets` had failed with `(403) Forbidden (Service Account Deleted)`). If a stale render shows that 403 again, re-render before assuming the token is bad.
- [ ] **qbert: roll upsight v0.3.2 (run on qbert only):** quit upsight on qbert, `git pull`, then `just bump-upsight`. It needs `nix`, so it fails with exit 127 on the Mac (tried 2026-10-09; it reverted `flake.lock` and left the tree on the old pin). The upsight flake input follows `main`. First refresh the upsight Nix hashes: upsight PR #193 (dompurify bump, merged 2026-10-09) changed `frontend/pnpm-lock.yaml`, so the `pnpmDeps` hash in `nix/upsight.nix` is stale and the bump fails on a hash mismatch. On qbert run `cd ~/git/upsight && git pull && just update-hashes`, then commit and push the `nix/upsight.nix` change to upsight `main` (a PR is fine, merge it before bumping). If it fails, read `/tmp/nixerator-rebuild.log`. The first launch applies DB migration v77 to the shared database, and an older upsight on another host can still open it. Only one machine may run upsight against the database at a time.
- [ ] **After the upsight bump:** open the Usage tab for a customer and click Refresh. Set Settings, Integrations, "Snowflake — Usage" to a custom path for `snowstorm` (a nix-installed app does not have `~/go/bin` on its PATH), and confirm `snowstorm login` has a valid session on that host. On Linux, snowstorm's SSO token caching defaults OFF and needs `client_store_temporary_credential = true` on the connection (see the snowstorm README), otherwise every command opens the browser. Check how qbert gets snowstorm and its `connections.toml`.
- [x] **claudoist hash:** fixed in claudoist #11.
- [ ] **Claude remote access to qbert:** a Claude session on the Mac could not SSH to `dustin@192.168.169.2` on 2026-10-09: the SSH agent refused to sign with all four keys (`agent refused operation`), so nothing ran. Unlock 1Password and approve its SSH agent prompts, check `ssh-add -l` lists the keys, then ask the session to retry its read-only probe (hostname, `nix`, running upsight, nixerator and upsight repo state). `just rotate-op-token` needs a desktop biometric prompt, so run it on the qbert desktop, not over SSH.
- [ ] **qbert:** `git pull`, prune stale plugins and cache dirs per `.claude/docs/claude-plugins.md` (now including `frontend-design@claude-plugins-official`), run `just qr` twice (the second run must show no capture diff), then `python3 ~/git/claude-skills/scripts/claude_stack.py drift --host qbert`. Activation now also deletes the five removed guard hooks from live `settings.json` and a user-scope `kong-konnect` from `~/.claude.json`; confirm both are gone.
- [ ] **srv:** srv builds (confirmed). Still to do: the same prune, `just qr` twice and drift steps, with `--host srv`.
- [ ] **kong-docs-rag on qbert:** GitHub auth for the private clone, `ollama pull nomic-embed-text`, set the plugin's `repo_path` (Nix does not apply manifest `config` yet), then the first `bin/kong-docs-rag index -data-dir data`. `go.mod` needs Go 1.26.6, so the activation build may fetch a toolchain.
- [ ] **Plugin secrets:** Nix does not apply per-plugin `config` or `secrets` from the manifest (`kode_apikey`, `kong-konnect`, `kong-tableau`). Set them on NixOS with `claude plugin configure` under `op run`. This now includes `kong-konnect`, since the plugin is the only source of that MCP server.
- [ ] **Janus on qbert (secrets broker, pinned input `janus` in `flake.nix`):** commit branch `feat/janus-service`, then `just qr`. The input is pinned by `rev`, so `nix flake update` does not move it; bump the rev only after reading the new Janus commits. Then follow `docs/ai/runbook.md` steps 5 and 5b in `bashfulrobot/janus`: create the identity as the service user (`sudo -u janus janus init --state-dir /var/lib/janus`), build the bundle as yourself and install it with `sudo install -o janus -g janus -m 0600`, restart, `janus unlock`. Stop any hand-started `janus serve` first: both want `127.0.0.1:8899`. Fix whatever breaks in the Janus repo with a test, not here.
- [ ] **Janus agent user:** `services.janus.agent` creates `agent` (no password, no wheel) and the shared workspace `/home/agent/git`. After the rebuild, check `id agent`, `ls -ld /home/agent/git` (`drwxrws---`) and that `agent` cannot read your home. Log in once with `janus-agent --repo <id> --project /home/agent/git/<repo> -- claude /login` (the agent has its own Claude login), then confirm `claude` works through the Janus proxy with the custom CA.
- [ ] **Agent workspace hygiene:** the agent can write hooks and `.envrc` files into `/home/agent/git` that run as you if you use git or direnv there without looking. Review a repo there before you work in it as yourself.
- [ ] **Janus, still unproven on real systems:** `kube-token` against a production cluster (it ran only on a throwaway k3d cluster), and `janus login` with a real OAuth app (GitHub, Google or Atlassian, each with its own refresh token rules).
- [ ] **Janus input on other hosts:** `janus` is a private repo fetched over `git+ssh`. Every host that evaluates this flake (srv, the Mac) needs GitHub SSH access, or evaluation fails with a fetch error even though only qbert enables the service.
- [x] **Flake input:** `nixos-hardware` dropped in #439.
- [ ] **Webinar tooling (deferred, webinar is developed on the Mac for now):** PR #430 added `gitleaks`, `pre-commit`, `pass`, `gnupg` (dev suite) and `kubectx`, `k3d`, `checkov` (k8s suite) without a Nix evaluation. Before using them on qbert: run `just build-host qbert`, then add a gpg-agent with a pinentry (`programs.gnupg.agent`, qbert has none) so `pass` can prompt, then `just qr`. `srv` already has `pass` and `pinentry-tty`.
- [ ] **Linux clipboard permission:** allow `Bash(wl-copy *)` in `modules/apps/cli/claude-code/config/settings.json`, then declare it in the manifest's `linux` profile in claude-skills.
- [x] **Guard hooks:** decision made and ported in claude-skills #68 (the five guards ship in dk >= 2.30.1). Nixerator's copies are removed in this PR. `git-sync`, `guard-generated-paths`, `guard-raw-nix` and the precompact/reinject hooks stay here (NixOS-only).
- [x] **1Password vault:** the remaining `op://nixerator/` refs (aha, wave, forgejo, restic, zai, github-pat) stay in the nixerator vault, which is repo-specific. Decided by Dustin.
