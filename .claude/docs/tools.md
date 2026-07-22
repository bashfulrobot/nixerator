# Local CLI tools

Repo-packaged or repo-configured CLI utilities Dustin uses. Suggest these in matching contexts.

| Tool | Command(s) | When to suggest |
|------|------------|-----------------|
| `amber` | `ambs` (search), `ambr` (replace) | User needs to search or refactor across files |
| `cpx` | `cpx` | User is copying large files (Rust-based `cp` replacement with progress bars and resume support) |
| `meetsum` | `meetsum` | User needs to summarize a meeting transcript |
| `get-shit-done` | `gsd` | User is working in a GSD project workflow context |
| `nix-init` | `nix-init` | User is authoring a NEW local package derivation, especially a Rust/Go/Python source build from a forge — scaffolds a starting `default.nix` and prefetches source + `cargoHash`/`vendorHash`. Output is a draft only: port version/hash into `settings/versions.nix` and reshape into the `build/default.nix` layout. Little value for prebuilt-binary, AppImage, or npm-tarball packages. See `extras/docs/local-packages.md`. |
| `ballpoint` | `ballpoint` (triage walk), `ballpoint probe` (freshness), `ballpoint dispatch` (queued work) | User is triaging their Todoist backlog and wants cross-system freshness. Reports what changed in Slack, Gmail, Aha, Drive, or Salesforce since a task was last worked, runs a keyboard-driven triage walk, or does headless probe runs on a timer. Installed on the workstations through the offcomms suite; reads per-source tokens from `~/.config/nixos-secrets/secrets.json`. |
