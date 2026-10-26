# Conventions

Workflow rules: how to build, lint, format, manage upgrades, and handle secrets in nixerator.

## Builds and rebuilds

- **Always use the justfile.** `just qr` (alias for `just quiet-rebuild`) for the current host; per-host aliases for other targets. Never run raw `sudo nixos-rebuild build/switch ...` — the justfile wraps rebuilds with logging, spinners, and post-rebuild hooks (voxtype-setup, etc.) that direct invocations bypass.
- **Don't run `nix build` directly to test configurations.** The justfile is the only sanctioned interface.
- **Quiet variants capture output:** `just quiet-rebuild` writes to `/tmp/nixerator-rebuild.log`; `just quiet-upgrade` writes to `/tmp/nixerator-upgrade.log`. **On failure, spawn a Nix subagent** to read the log and propose a fix — do **not** read the log in the main context (they're noisy and burn tokens).
- **Testing local hyprflake changes:** `just hyprflake-test` (alias `just hft`) rebuilds the current host with the `hyprflake` flake input overridden to a local working tree, so hyprflake changes can be tried without committing/pushing hyprflake or bumping `flake.lock`. Defaults to `~/git/hyprflake`; pass a path to test a different checkout/worktree (e.g. `just hft /home/dustin/git/.worktrees/hyprflake-feature`). It wraps `sudo nixos-rebuild switch --impure --flake .#<host> --override-input hyprflake path:<path>` and targets whichever host it runs on, like `just rebuild`.
- **Verifying a wrapped package's script content:** packages built with `wrapProgram`/`makeWrapper` (e.g. `render-secrets`) move the real script to `bin/.<name>-wrapped` and leave a tiny PATH-prefixing stub at `bin/<name>`. Grep the wrapped payload (or the derivation's `src`), never `bin/<name>`. The stub never holds the script body, so it always looks empty and will send you chasing a phantom "stale build".

## Upgrades

- **Never run upgrades unprompted.** Upgrades depend on upstream repos being pushed first.
- When asked to upgrade, use `just quiet-upgrade` (alias `just qu`).
- **The lock-bumping recipes commit and push `flake.lock` themselves.** This covers `upgrade`/`quiet-upgrade`, `bump-upsight` (alias `ub`), and `bump-hyprflake`. Each one auto-commits the refreshed lock after a successful rebuild and pushes it, gated to `main`, so running any of them **while on `main` moves the remote**. That is by design (the lock never lingers unpushed), but it is the one place where a build recipe writes to `origin/main` without being asked. On any other branch the commit stays local. Run from a branch or worktree if a push would be unwelcome.
- **Bumping a single input:** `just update <input>` re-locks one input without touching nixpkgs, then `just qr` builds it. This is the way through when a full `qu` is blocked by an unrelated upstream breakage.
- **Keeping hyprflake current:** `just bump-hyprflake` is the one command. It bumps and pushes hyprflake's own inputs in `~/git/hyprflake`, then updates the `hyprflake` input here, rebuilds, and commits + pushes `flake.lock`. It reverts the lock only if the new pin fails to build; a benign activation-unit failure keeps it (gated on the `activating the configuration` marker in the rebuild log). The `hyprflake-updates` notifier flags when to run it.

## Git

- **Never run `git commit` or `git push`.** The user handles commits.
- **`post-rebuild` is the other sanctioned exception**, alongside the lock-bumpers above. Its `commit_captures` helper stages and pathspec-commits the captured Claude Code config and `dank-profiles/` on every plain `just qr`, then pushes once if anything landed. Both the commit and the push are gated to `main`; on any other branch it only prints the diff for you to review. So a rebuild on `main` moves the remote by design, and that is not an agent violating the rule above.
- After making changes, suggest a conventional commit scope and title (e.g. `feat(fish): add zoxide integration`).
- **Do not run `git stash` (push/save).** A PreToolUse hook (`guard-git-stash`, shipped by the dk plugin) denies it before it runs, so the stash never reaches the shared stack. This is a hard deny, unlike the warn-level `bash-guard` that only nudges on `--no-verify`/`--force`. The stash stack lives at `refs/stash` in the repo's common git directory, which every worktree shares, so two agents stashing in two worktrees push onto the same stack and pop each other's entries. `git stash pop`, `apply`, `list`, `show`, `drop`, and `branch` stay allowed so a human can recover an existing entry. `git stash clear` is denied like a push, since it discards the whole stack.

### Worktree lifecycle

- A session cannot remove the worktree it stands in, and a guard hook blocks `git -C` into another checkout. After a merge, keep working in the same worktree: `git fetch origin main && git switch -c <next-branch> origin/main`. Branches that are not checked out can be deleted from inside (`git branch -D <name>`).
- When the line of work is finished, run `just prune-worktrees` from the **primary checkout** (dry run), then `just prune-worktrees --yes`. It removes only worktrees under `.claude/worktrees` that are clean, whose branch has a merged PR, and whose tip is the commit that PR merged. Anything else is listed as kept with the reason.

### Interrupt and shutdown pattern

- To park in-progress work (agent interrupt, shutdown, or handoff), commit it on the task branch instead of stashing: `git add -A && git commit -m "wip: <summary>"`. The commit lives under the worktree's own HEAD, isolated per worktree, survives a reboot, and (once pushed) is visible on another device, which a stash never is.
- Resume by unwinding the WIP commit back into the working tree: `git reset --soft HEAD^`. The changes return staged, ready to keep working, and the real commit replaces the `wip:` one.
- **`rebase.autoStash` stays enabled** and is deliberately not treated the same way. It is scoped to a single rebase and keeps its saved changes in rebase-internal state rather than the visible `refs/stash` stack, so it does not race the shared stack that manual stashing collides on. On the success path it re-applies and drops that state automatically; only a conflicting re-apply leaves an entry behind for you to resolve, and that entry is tied to the one rebase you started. That is why the ban targets *manual* `git stash`, which parks a lingering shared entry any other agent can pop.

## Lint and format

- Format with `nix fmt`.
- Lint with `statix` and `deadnix`.

## Path discipline

- Avoid host-specific or machine-local paths. Prefer `settings/globals.nix` so values flow through the global config layer.

## Secrets

- **All secrets live in the `nixerator` 1Password vault.** Nix-eval secrets render to `~/.config/nixos-secrets/secrets.json` via `just render-secrets`; Okular signature PNGs fetch to `~/.kde/share/icons/` via `just fetch-signatures`. See `extras/docs/secrets.md`.
- **Automation secrets live in gopass** (private repo `bashfulrobot/secauto`, key outside git), pulled to reader hosts by `apps.cli.secauto-pull`. Unattended jobs must not call `op`. Never run `gopass show`/`cat` or `pass show` in a model-visible shell. See "Automation secrets (secauto)" in `extras/docs/secrets.md`.
- **Never read `~/.config/nixos-secrets/` or `~/.config/op/`** from agent tooling — both paths are on Claude Code's Read `permissions.deny`. To inspect the schema, read `secrets.json.tpl` (placeholders only).
- **Never re-introduce `secrets/secrets.json`, `secrets/sg.png`, or `secrets/init.png`** in the repo. `.gitignore` blocks them; git-crypt has been retired (#86).
- Per-host network identity (Tailscale IPs, syncthing peer IDs) is NOT secret and lives in `settings/globals.nix` under `hosts.{qbert,srv}`.

## Searching nixpkgs

```bash
nix search github:NixOS/nixpkgs/nixos-unstable#PACKAGE-NAME --json
```
