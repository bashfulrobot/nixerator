---
name: secrets
description: Manage Dustin's secrets with gopass (the secauto store) and 1Password (op) on qbert. Use for any request to look up, add, change, rotate or delete a secret, or to check the gopass store and 1Password for drift.
compatibility: opencode
---

# Secrets on qbert

You run on the local model, so secret values stay on this machine. Values you
read appear in this session only, which lives on tmpfs and is deleted when you
exit.

## Where secrets live

- 1Password vault `nixerator` is the source for most secrets.
- gopass, the `secauto` store (private git repo `bashfulrobot/secauto`), is the
  snapshot that automation reads. qbert is the only writer. srv and the Mac pull
  every 15 minutes, so a pushed change reaches them within 15 minutes.
- An entry that exists only in gopass is not covered by
  `just import-secrets-to-gopass`. `--update` overwrites a mapped entry with the
  1Password value. To change a mapped value, change 1Password first, then run
  the import, so the next import does not undo your edit.
- `modules/apps/cli/render-secrets/gopass-map.tsv` in `~/git/nixerator` maps
  gopass entry names to 1Password items. Read it before changing an entry.

## Commands

Retrieval runs without a prompt:

- `gopass ls`, `gopass find <text>`, `gopass show -o <entry>` (value only)
- `gopass git status`, `gopass git log`, `gopass git diff`, `gopass git pull`
- `op vault list`, `op item list`, `op item get <item>`, `op read <op://path>`

These ask for approval, so state what you will change and why before you run
them:

- `gopass insert`, `generate`, `edit`, `mv`, `rm`, `sync`, `gopass git push`
- `op item create`, `edit`, `delete`
- `op run -- <command>`

These are blocked: `curl`, `wget`, `nc`, `ssh`, `scp`, `env`, `printenv`,
`op run --no-masking`.

## Rules

1. After a write to the store, show `gopass git status` and `gopass git log -1`
   so Dustin can see what was committed and pushed.
2. Never copy a secret value into a file, a commit message, a command line you
   did not need, or your final answer. Report entry names and success.
3. To use a secret in a command, prefer `op run` or have the script read it with
   `gopass show -o <entry>` itself, so the value is never typed by you.
4. `gopass insert` takes the value on stdin. Ask Dustin to type or paste the
   value into the prompt. Do not generate a replacement for a secret that
   another system issued.
5. Before `rm` or `mv`, run `gopass ls` for the entry and confirm nothing in
   `gopass-map.tsv` still references it.
6. `op` can open a desktop-app biometric prompt. If a command waits on one, stop
   and tell Dustin instead of retrying.
7. Unsure which store or mount is active: run `gopass mounts` and
   `gopass config` before writing.
