# Nixerator

Use GrayMatter for all project context. Search agent `nixerator` before reading files. Store new learnings via `memory_add` or `memory_reflect`. Reference docs live under `extras/docs/` if you need to verify anything.

## Documentation lookup

For repo languages/inputs, prefer the doc source that actually has good coverage instead of guessing:

- **Major upstream Nix tooling** — use **context7** first. Trigger column says when each one beats the alternatives:

  | Source | Library ID | Use it when |
  |---|---|---|
  | nixpkgs options/manual | `/websites/nixos_manual_nixpkgs_unstable` | Looking up a NixOS option (`services.foo.bar`) by keyword and you don't know the exact path |
  | nixpkgs general | `/nixos/nixpkgs` | Asking how a package is built/overridden, or about nixpkgs library functions (`lib.*`, `mkDerivation`, overlays) |
  | home-manager OPTIONS | `/websites/home-manager-options_extranix` | You need the right HM option name, its type, default, or example, and you DON'T already know the path. Beats grepping HM source for option discovery. Skip it if you already have the exact `programs.x.y` path — grep is faster |
  | home-manager guide | `/websites/nix-community_github_io_home-manager` | "How does home-manager *do* X" conceptual / workflow questions (activation, generations, integration with NixOS) — not option lookups |
  | stylix | `/websites/nix-community_github_io_stylix` | Any stylix theming, target enable/disable, color/font/wallpaper option |
  | disko | `/nix-community/disko` | Disk layout authoring, partition types, migration between table → gpt, disko-install usage |
  | flake-parts | `/websites/flake_parts` | Writing or restructuring a flake-parts module, perSystem patterns, importing community modules |
  | fish-shell | `/fish-shell/fish-shell` | Fish builtin/syntax/scripting questions — covers ~95% of fish surface |
- **Personal/niche flake inputs not indexed by context7** — use **gitmcp** (`mcp__gitmcp__fetch_generic_documentation` with owner+repo). Examples: `bashfulrobot/*`, `numtide/llm-agents.nix`, `gmodena/nix-flatpak`, `devmobasa/wayscriber`, `getpaseo/paseo`, `Lyndeno/apple-fonts.nix`, `Gerg-L/spicetify-nix`, `nix-community/nixos-vscode-server`.
- **Reading source code (not docs)** of any GitHub repo — gitmcp `search_generic_code`.

Skip the context7 `resolve-library-id` round-trip when the ID above already covers what you need.
