# Documentation sources

How to look up authoritative docs for the languages, tools, and flake inputs nixerator depends on. Skip context7's `resolve-library-id` round-trip when the IDs below already cover what you need.

## context7 (major upstream Nix tooling)

| Source | Library ID | Use it when |
|---|---|---|
| nixpkgs options/manual | `/websites/nixos_manual_nixpkgs_unstable` | Looking up a NixOS option (`services.foo.bar`) by keyword and you don't know the exact path |
| nixpkgs general | `/nixos/nixpkgs` | Asking how a package is built/overridden, or about nixpkgs library functions (`lib.*`, `mkDerivation`, overlays) |
| home-manager OPTIONS | `/websites/home-manager-options_extranix` | You need the right HM option name, its type, default, or example, and you don't already know the path. Beats grepping HM source for option discovery. Skip it if you already have the exact `programs.x.y` path — grep is faster |
| home-manager guide | `/websites/nix-community_github_io_home-manager` | "How does home-manager *do* X" conceptual / workflow questions (activation, generations, integration with NixOS) — not option lookups |
| stylix | `/websites/nix-community_github_io_stylix` | Any stylix theming, target enable/disable, color/font/wallpaper option |
| disko | `/nix-community/disko` | Disk layout authoring, partition types, migration between table → gpt, disko-install usage |
| flake-parts | `/websites/flake_parts` | Writing or restructuring a flake-parts module, perSystem patterns, importing community modules |
| fish-shell | `/fish-shell/fish-shell` | Fish builtin / syntax / scripting questions — covers ~95% of fish surface |

## gitmcp (personal / niche flake inputs not indexed by context7)

Use `mcp__gitmcp__fetch_generic_documentation` with owner + repo for:

- `bashfulrobot/*`
- `numtide/llm-agents.nix`
- `gmodena/nix-flatpak`
- `Lyndeno/apple-fonts.nix`
- `Gerg-L/spicetify-nix`

## Reading source code (any GitHub repo)

`mcp__gitmcp__search_generic_code` — use when the question is "how does this code work" rather than "what are the docs."
