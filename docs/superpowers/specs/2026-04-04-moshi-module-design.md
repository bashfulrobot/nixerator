# Moshi Module Design

## Overview

A NixOS system module that provides persistent remote session access via mosh and tmux, enabled through the AI suite for workstations.

## Module

- **Path:** `modules/system/moshi/default.nix`
- **Namespace:** `system.moshi`
- **Option:** `system.moshi.enable` (bool, default false)
- **Enabled from:** `modules/suites/ai/default.nix`

## Components

### Mosh

- Installs `pkgs.mosh` (client + server)
- Opens UDP 60000-61000 on the firewall
- No systemd service needed; mosh-server is invoked on demand via SSH
- Does not touch or duplicate any SSH configuration

### Tmux (via Home Manager `programs.tmux`)

Sane defaults:

| Setting | Value | Reason |
|---------|-------|--------|
| mouse | true | Scroll and pane selection |
| historyLimit | 50000 | Large scrollback |
| baseIndex | 1 | Windows/panes start at 1 |
| terminal | tmux-256color | Proper color support |
| escapeTime | 0 | No delay for editors |
| aggressiveResize | true | Better multi-client sizing |
| prefix | Ctrl-a | More ergonomic than Ctrl-b |
| keyMode | vi | Vi keybindings in copy mode |

## Constraints

- Must not interfere with `system.ssh` module
- No tmux plugins, themes, or status bar customization
- No systemd services
