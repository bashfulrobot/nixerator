# Nixerator

## Rules

- Never commit plaintext secrets; use `secrets/`.
- Avoid host-specific or machine-local paths; prefer `settings/globals.nix`.
- Use `nix fmt` and `statix` + `deadnix`.
- Never run `nixos-rebuild` or `git commit`/`git push` — the user handles rebuilds and commits. After changes, suggest a conventional commit scope and title (e.g., `feat(fish): add zoxide integration`).

## Docs (open only when needed)

Open these lazily when a relevant topic comes up. Do not read them all upfront.

**Core architecture:**
- `extras/docs/architecture.md` -- directory structure, flake organization, module system
- `extras/docs/module-development.md` -- creating new modules, templates, auto-discovery
- `extras/docs/local-packages.md` -- module-local package derivations (build/)
- `extras/docs/external-deps.md` -- primary flake inputs (hyprflake, stylix, disko, etc.)

**Operations:**
- `extras/docs/commands.md` -- justfile shortcuts for rebuilds, updates, maintenance
- `extras/docs/secrets.md` -- git-crypt secrets setup and usage
- `extras/docs/ssh.md` -- SSH server/client config and host aliases
- `extras/docs/helpers.md` -- reset-home-permissions.sh and similar scripts

**Hosts and setup:**
- `extras/docs/hosts.md` -- active hosts (donkeykong, qbert, srv) and their configs
- `extras/docs/adding-hosts.md` -- step-by-step guide to add new hosts
- `extras/docs/bootstrap.txt` -- NixOS installation procedure with disko
- `extras/docs/vm-development.md` -- dev VM setup with virtiofs

**Desktop and GUI:**
- `extras/docs/hyprland-windowrules.md` -- Hyprland 0.53+ block syntax for window rules
- `extras/docs/google-chrome.md` -- Dark Reader theme generation via Stylix
- `extras/docs/webapps.md` -- declarative web app modules
- `extras/docs/gpu-reference.md` -- GPU hardware and driver config per host

**Tools and integrations:**
- `extras/docs/tools.md` -- installed CLI tools (amber, cpx, meetsum, etc.)
- `extras/docs/gcmt.md` -- interactive conventional commit tool with AI bodies
- `extras/docs/claude-plugins.md` -- Claude Code plugin/skills manager
- `extras/docs/todoist-report.md` -- Todoist API query tool for project status
- `extras/docs/yepanywhere.md` -- mobile supervision for Claude Code

## Tools

- To search nixpkgs unstable: `nix search github:NixOS/nixpkgs/nixos-unstable#PACKAGE-NAME --json`