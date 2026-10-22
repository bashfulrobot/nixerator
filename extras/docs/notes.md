# Notes system

Plain folders of markdown under `~/Notes`, synced by Syncthing, indexed by zk,
read in a terminal with markless, in a GUI with Typora, and on a phone or
tablet through Weave over Tailscale. Module: `modules/apps/cli/notes`.

## Rules

- A note is a `.md` file. No database, no app-owned format.
- Every folder has its own `media/` subfolder. A note links its images as
  `![](media/<name>)`, relative to the note.
- Media filenames are unique across the whole tree. `notes-media` adds a
  `YYYYMMDD-HHMMSS-` prefix. Weave needs this (see "Phone and tablet").
- The root `~/Notes/media` is the one exception. It is a derived symlink farm
  for Weave, ignored by Syncthing, and holds no real files.
- Filenames are unique per note, so two notes never share a stem: date-prefixed
  (`20261022-1430-title.md`).

## Folder hierarchy

Defined in `cfg/hierarchy.txt`. `notes-init` creates it, each folder with a
`media/` subfolder. Edit that file and rerun `notes-init` to add folders.

| Folder | Holds |
|---|---|
| `00-inbox` | Unsorted capture. Triage weekly and keep it empty. The only transient bucket. |
| `10-work/kong/accounts` | One subfolder per customer account. |
| `10-work/kong/meetings` | Meeting notes (meeting template). |
| `10-work/kong/one-on-ones` | 1:1s (meeting template). |
| `10-work/kong/initiatives` | One subfolder per internal project. |
| `10-work/kong/playbooks` | Repeatable processes for customer work. |
| `10-work/kong/enablement` | Training and talk material. |
| `20-technical/nixos` | NixOS, Nix, home-manager. |
| `20-technical/kubernetes` | Kubernetes, Flux, Helm. |
| `20-technical/api-gateway` | Kong, gateways, API design. |
| `20-technical/networking` | DNS, VPN, Tailscale, firewalls. |
| `20-technical/homelab` | Hosts, VMs, self-hosted services. |
| `20-technical/programming` | Languages and libraries. |
| `20-technical/ai` | LLMs, agents, prompts. |
| `20-technical/tooling` | CLI tools and editors. |
| `30-personal/health` `finance` `home` `travel` `family` `learning` | One topic each. |
| `40-reference/cheatsheets` | Lookup tables. |
| `40-reference/how-to` | Step-by-step procedures (how-to template). |
| `90-archive` | Finished work moved out of the live folders. |

If a note fits two folders, put it in one and link it from the other.

## Commands

| Command | Does |
|---|---|
| `notes` | Fuzzy-pick a note (fzf). Enter views in markless, `ctrl-o` opens the GUI, `ctrl-e` edits. |
| `notes [query]` | Same picker with the query prefilled. |
| `notes -s [query]` | Full-text search as you type (`zk --match`). |
| `notes -t tag` | Pick among notes with a tag. |
| `notes -l` | Fuzzel menu, opens the GUI viewer. Bound to `SUPER+CTRL+N` on Hyprland when `apps.cli.notes.keybind = true` (qbert). |
| `notes-new [title]` | Pick a folder, create the note from its template, open `$EDITOR`. |
| `notes-media NOTE [FILE]` | Copy a file (or the clipboard image) into the note's `media/` and print the link. `--append` first adds it to the note. |
| `notes-open [--gui\|--edit] FILE` | Open in markless (default), the GUI viewer, or `$EDITOR`. |
| `notes-init [--update]` | Create folders, `.stignore`, `.zk/config.toml`, templates. `--update` overwrites config and templates. |
| `zk recent`, `zk orphans`, `zk tagged TAG` | Aliases from `.zk/config.toml`. |

NixOS runs `notes-init` on every rebuild activation. It never overwrites.

## Viewer and editor

- Terminal: markless renders in place with inline images. `--watch` reloads
  on change.
- GUI: Typora (`apps.gui.typora`, in `suites.offcomms`) renders markdown as you
  read it, so a file opens in a rendered view and edits in place. It has no
  separate read-only mode. `notes-open --gui` prefers Typora, then Zed, then
  the OS default. Set `NOTES_GUI` to force a command.
- Zed: opens the source. Open the rendered view with the `markdown: open preview`
  action (Linux default `ctrl-shift-v`). LIKELY, not checked on this host.
  Zed has no setting that opens markdown in preview automatically (UNVERIFIED).
- If Typora is missing after a rebuild, check that `suites.offcomms` is enabled
  on the host. `apps.gui.typora.enable` is the only switch.

## Sync

Syncthing folder `notes` (path `~/Notes`, staggered versioning) is declared in
`modules/apps/cli/syncthing`. It has no peers yet. To add one:

1. Make sure the device has a `syncthing_id` in `globals.hosts` (the Mac,
   `MH36P2YMHX`, already does) and is listed in the host's `devices` block in
   the syncthing module.
2. Add the device name to `folders."notes".devices`.
3. Rebuild, then accept the folder on the other device.

`notes-init` writes `~/Notes/.stignore` once and never rewrites it, so edit
that file to change the list. It keeps `.zk/notebook.db*` (rebuilt per device), the root `media/`
farm, `.DS_Store` and sync-conflict files out of the sync. The zk config and
templates in `.zk/` do sync, so one edit reaches every device.

## Phone and tablet

Weave (`apps.cli.notes.weave`) is a single-binary web frontend for a zk
notebook. It runs on qbert as `weave.service`, bound to qbert's Tailscale IP on
port 8000, and the firewall opens that port on `tailscale0` only.

1. Install Tailscale on the phone or tablet and sign in to the same tailnet.
2. Open `http://100.74.137.95:8000` (qbert's Tailscale IP).
3. Optional HTTPS and a stable name: `tailscale serve --bg 8000` on qbert, then
   open the `https://qbert.<tailnet>.ts.net` address it prints.
4. Add to Home Screen from the browser share sheet.

Login is off by default. The tailnet is the boundary. To require a password,
create an env file outside the repo containing `WEAVE_PASSWORD=...` (mode 600)
and set `apps.cli.notes.weave.passwordFile` to its path.

Limits:

- Weave maps `![](media/x.png)` to `/media/x.png`, one directory for the whole
  notebook. `notes-weave-media` (timer, every 2 minutes, and before each Weave
  start) links every per-folder `media/` file into `~/Notes/media`. A name that
  appears twice keeps the first file and logs a warning.
- Weave only serves the host it runs on. When qbert is off, the phone cannot
  read notes. Running Weave on an always-on host that also syncs the notebook
  fixes that.
- Without a password anything on the tailnet can edit notes through Weave. The
  build prints a warning in that case.
- `weave.service` runs sandboxed: `ProtectHome=tmpfs` hides everything in
  `$HOME` except `~/Notes`, so a Weave bug cannot reach `~/.ssh` or the rendered
  secrets.
- Weave follows the `~/Notes/media` symlinks: checked against weave 0.4.0, the
  route returns 200 for a linked image.

## macOS port checklist

The scripts in `cfg/` are plain bash 3.2, no GNU-only flags, and read
`NOTES_DIR` (default `~/Notes`) and `NOTES_SHARE` (the directory holding
`hierarchy.txt` and `zk/`, default: next to the script).

1. Install: `brew install zk fzf bat ripgrep pngpaste choose-gui` and Typora
   (cask). markless: `cargo install markless` (the upstream README's install
   command; nixerator pins v0.9.29).
2. Copy `modules/apps/cli/notes/cfg/` to a stable path, for example
   `~/.local/share/notes`, and put the scripts on `PATH` without the `.bash`
   suffix. Set `NOTES_SHARE` to that directory.
3. `export NOTES_DIR=~/Notes ZK_NOTEBOOK_DIR=~/Notes`, then run `notes-init`.
4. Syncthing: add this Mac as a device on qbert's `notes` folder (see Sync).
   Mac paths: `~/Notes`.
5. Launcher: `notes -l` uses `choose` on macOS. Bind it with Raycast or a
   Shortcuts quick action, since there is no fuzzel.
6. Image paste: `notes-media` uses `pngpaste` on macOS.
7. Do not run Weave on the Mac unless it is the always-on host. Weave's
   `notes-weave-media` step is Linux and macOS safe.

## Troubleshooting

- `notes: no notebook at ...` means `.zk/` is missing. Run `notes-init`.
- Images blank in Weave: the note links an image that is not under a `media/`
  folder, or two images share a name. Run `notes-weave-media` and read stderr.
- `weave.service` fails to start after boot: Tailscale was not up yet. The unit
  restarts every 10 seconds until the address exists.
