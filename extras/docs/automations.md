# Automations

Scheduled jobs write markdown reports into `~/automations`, a Syncthing folder
shared by srv, qbert and the Mac. Any workstation reads a report without asking
the host that ran the job.

## Layout

```
~/automations/reports/<host>/<job>/YYYY-MM-DD.md
~/automations/reports/<host>/<job>/latest.md
```

`<host>` is `srv`, `qbert` or `MH36P2YMHX` (the Mac). A host writes only under
its own directory, so Syncthing never has two writers on one file and creates no
`.sync-conflict` copies. Each report starts with YAML front matter: `host`,
`job`, `status` (`ok`, `degraded` or `failed`) and `run_at` (UTC).

Job definitions live in git (this repo for srv and qbert). Job state, such as
cursors and last-run markers, stays local on the host and is not synced.

## Topology

The Mac peers only with qbert. srv peers only with qbert. qbert holds the folder
for both and relays between them. srv and the Mac never connect directly.
UNVERIFIED until a report written on srv shows up on the Mac.

## Module

`server.automations` (`modules/server/automations`) provides:

- `automations-report <job> <status>`: reads a markdown body on stdin, writes
  the dated file and `latest.md` by rename, and prunes dated files older than
  `keepDays` (default 30).
- `heartbeat`: a daily job (06:30, `Persistent=true`) that reports uptime and
  failed units. If it fails, `automations-heartbeat-failed` rewrites `latest.md`
  with `status: failed`, so the Mac sees the failure and not a stale `ok`.

srv imports the module by hand in `hosts/srv/modules.nix`. qbert auto-imports it
and leaves it off.

## Rollout

srv's Syncthing device ID exists only after its first start.

1. Rebuild srv (`just qr` on srv, or `just rr srv`).
2. Read srv's device ID from its Syncthing UI (`http://100.64.187.14:8384`, or
   `syncthing --device-id`). Device IDs are not secrets.
3. Add it as `syncthing_id` under `hosts.srv` in `settings/globals.nix`.
4. Rebuild qbert. It now lists srv as a peer on the `automations` folder.
5. On the Mac, add `automations|$HOME/automations|<simple versioning>|automations`
   to `folder_table` in `~/git/donkeykong/syncthing.sh` (plus an `automations`
   ignore set), then run `just syncthing`. The folder ID must match this repo's
   `automations` attribute. The Mac side lives in donkeykong, not here.
6. Accept qbert's pending device and folder offers on srv if they appear.

## Adding a job

Write a script that ends with `... | automations-report <job> <status>`, run it
from a `systemd.services` unit plus a timer with `Persistent = true`, and add
`onFailure` to a unit that calls `automations-report <job> failed`. Jobs that
need secrets read them from the secauto gopass store, never `op`.
