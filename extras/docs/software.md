# Installed Software

Complete inventory of software managed by this NixOS configuration.

## CLI Tools

| Software              | Description                                                                           | Source                           |
| --------------------- | ------------------------------------------------------------------------------------- | -------------------------------- |
| Amber                 | Code search (`ambs`) and replace (`ambr`) tool                                        | Local build                      |
| Claude Code           | AI coding assistant CLI with MCP servers, LSP, status line, hooks, skills, and agents | Local build                      |
| Clay                  | Web UI for Claude Code with headless server mode and PIN auth                         | Local build (npm)                |
| CPX                   | Fast Rust-based `cp` replacement with progress bars and resume; aliased as `cp`       | Local build                      |
| Docker                | Container runtime with daemon, socket access, and CLI tools                           | nixpkgs                          |
| Fish                  | Shell with custom functions (kcfg, tcfg, copy, kns) and navigation aliases            | nixpkgs                          |
| GCMT                  | Interactive conventional commit tool for structured git messages                      | Local script                     |
| Gemini CLI            | Google Gemini AI CLI with commit helper (`gcommit`) and humanizer skill               | nixpkgs                          |
| Git                   | Version control with gcom (branch/worktree management), git-crypt, lazygit, gh CLI    | nixpkgs                          |
| Gurk                  | Signal Messenger TUI client                                                           | Local build                      |
| GWS                   | Google Workspace CLI for Drive, Gmail, Calendar, Sheets, Docs, Chat, Admin            | Local build                      |
| Helix                 | Terminal text editor with LSP support and language-specific formatters                | nixpkgs                          |
| JWTX                  | Terminal JWT decoder/encoder TUI                                                      | Local build (Go)                 |
| Kubectl               | Kubernetes CLI with OIDC auth, kubecolor, kubelogin, krew, ktop                       | nixpkgs                          |
| Kubernetes MCP Server | MCP server for Kubernetes cluster interaction from Claude Code                        | Local build (npm)                |
| Localsend-rs          | CLI for local file/text transfer via LocalSend protocol                               | Local build (Rust)               |
| LSWT                  | List Wayland toplevels (window manager introspection)                                 | Local build                      |
| Meetsum               | AI-powered meeting summarizer using Claude with file browser                          | Local build                      |
| Nix tooling           | cachix, comma, deadnix, nix-index, nixd, nixfmt, statix, nh                           | nixpkgs                          |
| Nix Search TV         | Fuzzy search for Nix packages across multiple indexes with fzf                        | nixpkgs                          |
| Ollama                | Local LLM server with configurable acceleration (CPU/CUDA/ROCm/Vulkan)                | nixpkgs                          |
| Pandoc                | Document converter with LaTeX/PDF support and `md2pdf` fish function                  | nixpkgs                          |
| Percollate            | Web-to-PDF converter with sitemap support and `web2pdf` fish function                 | nixpkgs                          |
| Plannotator           | Interactive plan review and annotation tool for AI coding agents                      | Local build                      |
| Reap                  | Claude Code context reaper for managing conversation context                          | Local build (npm)                |
| Restic                | Backup suite with restic, backrest UI, and autorestic                                 | nixpkgs                          |
| Salesforce CLI        | Salesforce development and administration CLI (`sf`)                                  | Local build                      |
| Shadowenv             | Directory-based environment variable switching with fish integration                  | nixpkgs                          |
| Slack Token Refresh   | Extract Slack xoxc/xoxd tokens from Chrome via Playwright                             | Local build                      |
| Slack Tracker         | CLI for finding and tracking unanswered Slack messages                                | Local script                     |
| Spotify (ncspot)      | Terminal Spotify client with MPRIS support and save-playing helper                    | nixpkgs                          |
| Starship              | Modern shell prompt with git status and language symbols                              | nixpkgs                          |
| Stop Slop             | Claude Code skill for detecting and removing AI writing patterns                      | Local (GitHub fetch)             |
| Superpowers           | Agentic skills framework (plugin) for Claude Code                                     | Plugin (claude-plugins-official) |
| Syncthing             | Peer-to-peer file synchronization with host-specific config and versioning            | nixpkgs                          |
| Tailscale             | Zero-config mesh VPN with systemd service                                             | nixpkgs                          |
| Todoist Report        | CLI for generating Todoist project status reports                                     | Local script                     |
| VS Code Server        | VS Code remote SSH server support                                                     | nixpkgs (module input)           |
| wkhtmltopdf           | HTML-to-PDF converter with `wkhtmltopdf-domain` helper                                | nixpkgs                          |
| Worktree Flow         | AI-powered isolated worktree workflows for GitHub issues                              | Local scripts                    |
| Zoxide                | Smarter directory navigation with zoxide.fish plugin for tab completion               | nixpkgs                          |

## GUI Applications

| Software       | Description                                                                   | Source                         |
| -------------- | ----------------------------------------------------------------------------- | ------------------------------ |
| 1Password      | Password manager with native browser messaging (Chromium, Zen)                | nixpkgs                        |
| Cameractrls    | Camera controls utility for Linux webcams                                     | Flatpak                        |
| Comics         | Komikku manga reader + comics-downloader for downloading comics/manga         | nixpkgs + local build          |
| Ghostty        | Modern terminal emulator with Fish integration and Bat syntax highlighting    | nixpkgs                        |
| Google Chrome  | Web browser with Stylix-generated Dark Reader theme; stable and Dev channels  | Flake input (browser-previews) |
| Helium         | Privacy-focused Chromium-based browser (beta) with 1Password integration      | Local build                    |
| Insomnia       | API client (Kong) with local package override for newer versions              | Local build                    |
| Insync         | Google Drive sync client with optional Nautilus integration                   | nixpkgs                        |
| LocalSend      | Local file sharing utility with firewall integration                          | nixpkgs                        |
| Morgen         | Calendar application with Hyprland window tiling rule                         | nixpkgs                        |
| Obsidian       | Notes application with obsidian-export tool                                   | nixpkgs                        |
| Okular         | PDF viewer with signature/initials stamp support; default PDF handler         | nixpkgs (KDE)                  |
| Signal Desktop | Encrypted messaging app with optional GNOME libsecret integration             | nixpkgs                        |
| Spicetify      | Spotify desktop client with theming                                           | nixpkgs (spicetify-nix input)  |
| Typora         | Markdown editor with optional Nautilus context menu integration               | nixpkgs                        |
| VS Code        | Code editor with Stylix theming, Copilot, and Nautilus integration            | nixpkgs                        |
| Wayscriber     | Real-time screen annotation tool for Wayland with keybindings                 | Flake input                    |
| Web App Hub    | Progressive web app creator with extraction script                            | Flatpak                        |
| Zed            | Code editor with extensive LSP support, remote dev, and Claude AI integration | nixpkgs                        |

## Web Apps

Declarative web app wrappers created via `mkWebApp` with desktop entries and custom icons.

| App       | URL Target                          |
| --------- | ----------------------------------- |
| Calendar  | Google Calendar                     |
| Clari     | Clari revenue intelligence platform |
| Kong Docs | Kong API gateway documentation      |
| Mail      | Gmail                               |
| Slack     | kongstrong.slack.com                |
| Zoom      | Zoom video conferencing             |

## Suites (Module Aggregators)

| Suite          | Packages Included                                                                                            |
| -------------- | ------------------------------------------------------------------------------------------------------------ |
| Terminal       | Ghostty, Fish, Starship, Zoxide, bat, dust, eza, fd, ripgrep, tokei, procs, sd, bottom, hyperfine            |
| Kubernetes     | kubectl, talosctl, omnictl, cilium-cli, eksctl, fluxcd, helm, kubeseal, kustomize, minikube, k9s             |
| Infrastructure | Docker, jwtx, cloud-utils, AWS IAM authenticator, Google Cloud SDK, OpenTofu, Pulumi, Terraform, wake-on-LAN |
| Security       | 1Password GUI and CLI                                                                                        |

## System Modules

| Module                | Description                                                                                                   |
| --------------------- | ------------------------------------------------------------------------------------------------------------- |
| Apple Fonts           | SF Pro, SF Mono Nerd, and New York fonts                                                                      |
| Flatpak               | Declarative Flatpak management via nix-flatpak with auto-update                                               |
| GNOME Online Accounts | Google Drive and cloud integration in Nautilus (accounts-daemon, evolution-data-server, GVFS, gnome-keyring)  |
| SSH                   | OpenSSH server/client with predefined host aliases (camino, budgie, feral, github, bitbucket, qbert, srv, dk) |

## Server Modules

| Module          | Description                                                                   |
| --------------- | ----------------------------------------------------------------------------- |
| KVM             | QEMU/KVM virtualization with virt-manager, virt-viewer, SPICE USB redirection |
| NFS             | NFS server with configurable exports and bind mounts                          |
| Restic (server) | Restic backup with systemd timer, backup-mgr Fish CLI, and Backrest UI        |
| Whisper Server  | whisper.cpp HTTP transcription server with optional Vulkan GPU acceleration   |

## Dev Modules

| Module | Description                                                          |
| ------ | -------------------------------------------------------------------- |
| Go     | Go tooling with Clang support for CGO (CC/CXX environment variables) |

## Disabled Modules

Modules that exist but are currently disabled (set to `false` or commented out in suites):

| Module              | Reason                                    |
| ------------------- | ----------------------------------------- |
| Brave               | Disabled in browsers suite                |
| GSD (Get Shit Done) | Disabled; removed from claude-code module |
| Ollama              | Disabled in AI suite                      |
| OpenSpec            | Disabled in AI suite                      |
| Termly              | Disabled in AI suite                      |
| VS Code             | Disabled in dev suite (using Zed)         |

## Locally-Built Packages (versions.nix)

All version-pinned packages managed in `settings/versions.nix`:

**CLI:** amber, clay, cpx, gurk, gws, jwtx, kubernetes-mcp-server, lswt, meetsum, plannotator, reap, salesforce-cli

**GUI:** comics-downloader, helium, insomnia

**Fish plugins:** zoxide.fish
