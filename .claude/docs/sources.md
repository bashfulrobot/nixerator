# Documentation sources

How to look up authoritative docs for the languages, tools, and flake inputs nixerator depends on.

## Major upstream Nix tooling

Read these through gitmcp (below) or the official manuals; no docs-indexing MCP is configured.

| Source | Repo / manual | Use it when |
|---|---|---|
| nixpkgs options/manual | `NixOS/nixpkgs`, nixos.org manual | Looking up a NixOS option, how a package is built/overridden, or nixpkgs `lib.*` functions |
| home-manager | `nix-community/home-manager` | The right HM option name, type, default, or example, and conceptual "how does HM do X" questions |
| stylix | `nix-community/stylix` | Any stylix theming, target enable/disable, color/font/wallpaper option |
| disko | `nix-community/disko` | Disk layout authoring, partition types, disko-install usage |
| flake-parts | `hercules-ci/flake-parts` | Writing or restructuring a flake-parts module, perSystem patterns |
| fish-shell | `fish-shell/fish-shell` | Fish builtin / syntax / scripting questions |

## gitmcp (any GitHub repo, including personal / niche flake inputs)

Use `mcp__gitmcp__fetch_generic_documentation` with owner + repo for:

- `bashfulrobot/*`
- `numtide/llm-agents.nix`
- `gmodena/nix-flatpak`
- `Lyndeno/apple-fonts.nix`
- `Gerg-L/spicetify-nix`

## Reading source code (any GitHub repo)

`mcp__gitmcp__search_generic_code` — use when the question is "how does this code work" rather than "what are the docs."
