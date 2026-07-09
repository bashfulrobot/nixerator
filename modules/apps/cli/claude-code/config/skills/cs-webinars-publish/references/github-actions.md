# What the cs-webinars GitHub Actions do

Context for what happens after a PR merges, so you can set expectations and know where to look when something doesn't publish. Mirrors the repo's `docs/github-actions.md`.

Three workflows run on merges to `main`.

## Deploy docs — `.github/workflows/docs.yml`

Triggers on any push to `main` touching `docs/**`. Downloads a pinned, checksum-verified Zola binary, runs `zola check` to catch broken links or config errors, builds with `zola build`, and deploys to GitHub Pages. The site computes each webinar's download link from its content filename (the same slug used for the release tag and zip name), so there's no placeholder-substitution step.

## Release webinar assets — `.github/workflows/release-webinar.yml`

Triggers on any push to `main` touching `webinars/**`. Diffs the push to find which folders under `webinars/` changed, then for each one:

1. Zips the folder into `<slug>.zip`.
2. Publishes — or updates, if the tag already exists — a GitHub Release tagged with the folder's slug, with the zip attached.

Because it updates in place, editing a session's folder later re-zips and re-publishes the same release, so the docs download link never changes.

## Secret scan — `.github/workflows/secret-scan.yml`

Runs on **every PR into `main`** and every push to `main`. Downloads a pinned, checksum-verified gitleaks and scans the full commit history for anything that looks like a credential. It reads its config from `.gitleaks.toml` at the repo root, which extends the default ruleset with a short allowlist of values confirmed safe to publish. When it flags something you know is safe, add a scoped allowlist entry there rather than merging past the failure — see `secret-scan.md`.

## Where to check when something breaks

All three show up under the repo's **Actions** tab.

- A failed **docs** or **release** run means the site or a release didn't publish — read the job logs there first.
- A failed **secret scan** means it found something that looks like a credential. Don't merge until you've confirmed what it flagged and either removed it (rewriting history if it already landed in a commit) or, if it's genuinely safe, allowlisted it per `secret-scan.md`.
- **Fork PRs are a special case:** GitHub holds their workflow runs in an `action_required` state until a maintainer approves them from the Actions tab. A fork PR showing no checks usually just means nobody's approved the run yet — not that the workflows didn't apply.
