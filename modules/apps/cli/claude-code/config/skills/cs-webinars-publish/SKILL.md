---
name: cs-webinars-publish
description: Publish a webinar/session's assets (slides, sample code, scripts) and its docs-site page to the KongHQ-CX/cs-webinars repo as a pull request. Use whenever the user wants to post, publish, add, or upload a webinar or session's materials to cs-webinars, prep a cs-webinars PR, or says things like "add my webinar to cs-webinars", "publish the hardening-konnect session assets", "put the slides up on the webinars repo", or "make a webinar page for the site". Also use when a cs-webinars secret scan (gitleaks) flags a value and the user needs to clear it safely — this skill enforces separation of duties: the PR author proposes an allowlist entry but a reviewer authorizes it, and the author never merges past a red scan. Covers the folder/slug convention, the Zola content-page front matter, a local gitleaks pre-check, and what the release/docs GitHub Actions do on merge.
argument-hint: "<session title or path to the assets>"
allowed-tools: ["Bash", "Read", "Write", "Edit", "Grep", "Glob", "Skill"]
---

## What this skill does

Walks a webinar's materials into the `KongHQ-CX/cs-webinars` repo the way the repo's own docs expect, then stops at an open pull request. Merging is someone else's call — see the security rule below and never merge to `main` yourself.

The repo is the source of truth. If any convention here disagrees with the repo's `docs/adding-webinar-assets.md`, `docs/overriding-a-safe-secret-scan.md`, or `docs/github-actions.md`, the repo wins — read them and reconcile before acting.

Work from a local clone of `git@github.com:KongHQ-CX/cs-webinars.git`. If the user is already in one, use it; otherwise clone it somewhere sensible and tell them where.

## The publish workflow

Do these in order. Steps 3 and 5 are the secret checks — don't skip them, and don't collapse them into one.

### 1. Pick the slug

The slug is `YYYY-MM-topic-slug`, and it is used in three places that must all agree: the asset folder name, the docs-page filename, and the eventual release tag. Derive it once, up front.

- `YYYY-MM` is the session's month. The docs page's `date` uses the **first of that month** (`YYYY-MM-01`) — the folder granularity is monthly, so the day is a convention, not the real session date.
- `topic-slug` comes from the session's **registration-page title**, kebab-cased and trimmed if it's long. Match what attendees already saw when they signed up, so the two line up. Ask the user for the registration title (or link) if you don't have it — don't invent a slug.

Example: a July 2026 "Hardening Kong Konnect" session → `2026-07-hardening-konnect`.

### 2. Create the asset folder and add the files

Create `webinars/<slug>/` and drop in what the session actually used: slides, sample code, demo scripts. Rules from the repo:

- Keep each file under GitHub's 100 MB limit.
- **Leave the recording out of the repo.** Link to wherever it's hosted (see the page's `recording_url` in step 4) instead of committing a video.

### 3. Self-check for secrets — before you commit

The secret scan in CI is a backstop, not your first line of defense. Check the files yourself first. Sample code and demo scripts are where credentials most often slip in — API keys, tokens, passwords, real endpoints with real auth.

Grep the folder for the obvious shapes and read anything that looks live:

```bash
grep -rniE 'api[_-]?key|secret|token|password|passwd|bearer|-----BEGIN|authorization' webinars/<slug>/
```

If you find a real credential (anything that grants access to a real system, account, or paid service): remove it, and if it already landed in a commit, rewrite history — don't just delete it in a later commit. If a flagged value is genuinely throwaway sample material, that's the allowlist path, and it has its own rules — see **"If the scan flags something"** below.

### 4. Add the docs-site page

Create `docs/zola/content/webinars/<slug>.md` so the session shows up on the site. TOML front matter, then a one-or-two-sentence body:

```
+++
title = "<Webinar title>"
date = <YYYY-MM-01>
[extra]
recording_url = "<link>"
+++
<One or two sentences from the registration page describing what the session covered.>
```

- `title` is the session's title; `date` is the first of the month (step 1).
- `recording_url` under `[extra]` is optional. Include it if there's a recording — it renders a "Watch" button on the card. Point it at the on-demand registration page if that's where the recording lives. Omit the whole line if there's no recording.
- **The download link is computed by the site from the asset filename** — the same slug used for the release tag and zip name. There is no placeholder to fill in and nothing to hand-wire.
- **Body copy is reused from the registration page, not freshly written.** Use the registration description close to verbatim. Do not run it through the `humanizer` skill and do not invent marketing copy — it should match what attendees already read. (The *PR description* you write in step 6 is your own prose, so that one does get humanized.)

### 5. Run the same scan CI runs — locally, against your branch

```bash
gitleaks detect --source . --redact --no-banner
```

`no leaks found` with exit code `0` means you're clean (or your allowlist covers an intentional sample value). Any gitleaks 8.x build is fine locally; CI pins its own version and only needs to agree on the finding. If the scan flags something, go to the section below — do not push past a red result.

### 6. Open the PR — and stop there

Branch, commit, push, and open a pull request. Do **not** merge, and do **not** push to `main`.

- Write a short PR description (this prose is yours — run it through the `humanizer` skill before posting). Say what session it is and what's included.
- If the PR adds a `.gitleaks.toml` allowlist entry, call that out explicitly and flag it for a reviewer to authorize (see the security rule below).

### 7. What merging does (so you can tell the user what to expect)

Once a reviewer merges to `main`, the repo's workflows do the rest automatically — you don't touch releases or the site by hand:

- The **release** workflow zips `webinars/<slug>/` into `<slug>.zip` and publishes (or updates) a GitHub Release tagged `<slug>` with the zip attached. Editing the folder later re-zips and re-publishes the same release, so the docs download link never has to change.
- The **docs** workflow rebuilds the Zola site and redeploys it to GitHub Pages.

Details and where to look when one fails: `references/github-actions.md`.

## If the scan flags something (the security rule)

Read `references/secret-scan.md` before doing anything about a secret-scan finding. The short version, which this skill enforces on the author's side:

**You are the PR author. You may _propose_ that a flagged value is safe. You may not _authorize_ it, and you never merge past a red scan.**

- A finding is treated as real until proven otherwise. Only a value that (a) grants access to nothing real, (b) is sample material attendees regenerate or replace, and (c) would cost nothing if a stranger copied it out of the repo can be allowlisted. A "test" token that still works against a real API fails this — remove and rotate it.
- The sanctioned mechanism is a **scoped `.gitleaks.toml` allowlist entry**, matched to a single file path, with a written justification, added **in the same PR**. Draft it (template and rules in the reference), but treat it as a proposal.
- **The author does not self-approve.** Do not merge a PR that adds an allowlist entry on your own judgment, and do not use a repo admin's "merge past a failed check" button — even if you have the rights. That override lives only in that one merge; the finding comes back red on the next push and nobody can tell an approved exception from an accident. Hand the safety decision to a reviewer and let them approve the allowlist entry. That review *is* the authorization.

If the user wants this enforced by more than convention (so the author genuinely *can't* bypass it), the reference explains the repo-level settings that do that.

## References

- `references/secret-scan.md` — the full safe-override process: the three-part safety test, the `.gitleaks.toml` allowlist template, separation of duties, and repo-level enforcement.
- `references/github-actions.md` — what the three workflows do on merge and where to check when one breaks.
