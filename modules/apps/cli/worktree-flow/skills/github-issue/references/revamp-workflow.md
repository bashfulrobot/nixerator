# Revamp & CI-Fix Workflows

Two distinct post-push recovery paths that the state machine treats separately.

- **`revamp`** — a reviewer left `CHANGES_REQUESTED`. Human (or AI) judgment about code quality is required.
- **`ci_fix`** — CI went red after push. Diagnose the failure and fix it. No code-review evaluation needed.

Both end by looping back through `verify` so the full gate runs again.

---

## `revamp` — address review feedback

### Entry

`status` detects an open PR with `reviewDecision == CHANGES_REQUESTED` and advances `workflow_step` to `revamp`.

### Procedure

1. **Fetch review feedback**

   ```bash
   github-issue review-feedback <N>
   ```

   Returns `reviews` (high-level comments) and `inline_comments` (specific line feedback), plus `review_decision`.

2. **Evaluate technically — invoke `superpowers:receiving-code-review`**

   Do not blindly agree with every comment. For each piece of feedback ask:
   - Does the suggestion actually improve the code?
   - Is there a technical reason the current approach is better?
   - Is the feedback based on a misunderstanding of the codebase?

   If a suggestion is questionable, push back with evidence in a PR comment. If valid, address it.

3. **Implement fixes**

   Batch all minor findings into a single commit — the branch is squash-merged anyway, so individual review-fix commits just add noise. Log "Batched N minor fixes" in the transition note.

   Block-level issues (verdict=block): fix, verify, push before moving on.

4. **Verify — invoke `superpowers:verification-before-completion`**

5. **Push updates**

   ```bash
   github-issue push <N>
   ```

   The CLI rebases onto base first (silent), then pushes with `--force-with-lease` if the rebase rewrote history.

6. **Comment on the PR**

   ```bash
   gh pr comment <pr_url> --body "Addressed review feedback:
   - <item 1>
   - <item 2>"
   ```

7. **Transition back through verify**

   ```bash
   github-issue transition <N> verify \
     --note "Addressed <N> review comments — <brief>" \
     --detail-json '{"revamp_round": <round+1>}'
   ```

   The cycle repeats if the reviewer requests more changes. No round limit.

---

## `ci_fix` — post-push CI failure

### Entry

`status` detects an open PR where `gh pr checks` reports `FAILURE` or `ERROR` checks, while the workflow step is `waiting`, `push`, `review_dev`, or `review_security`. Reconciliation advances `workflow_step` to `ci_fix`.

### Procedure — do NOT invoke `receiving-code-review`

1. **Get structured failure data**

   ```bash
   github-issue check-ci <N>
   ```

   Returns `failing_checks` (name, conclusion, detailsUrl), `passing_checks`, `pending_checks`.

2. **Fetch failing job logs** for each failing check

   ```bash
   gh run view <run-id> --log-failed
   ```

   The `detailsUrl` from check-ci output contains the run id.

3. **Fix the failure**

   - Flaky test: stabilize or skip with issue reference
   - Real regression: fix the code
   - Environment / config drift: update the config
   - Do not paper over real failures

4. **Verify locally — invoke `superpowers:verification-before-completion`**

   Run the same suite that failed in CI to confirm local repro + fix.

5. **Push**

   ```bash
   github-issue push <N>
   ```

6. **Transition back through verify**

   ```bash
   github-issue transition <N> verify \
     --note "Fixed CI failure in <check-name>: <root cause>"
   ```

   The state machine continues forward from verify through push/review again — the review skills run again on the new diff.

---

## Merge conflicts encountered during either path

If `github-issue push` fails because the pre-push rebase conflicted, apply the **Merge Conflict Resolution** procedure from `SKILL.md`:

- Single attempt, no retry loops
- Hard-escalate on lockfile/migration/generated-file conflicts
- Hard-escalate when both a test file and its source file conflict
- Mandatory post-resolve verification
- On verification failure: `git rebase --abort` and hand off to the user with a clear status dump

Never use `git push --force` during revamp or ci_fix — always `--force-with-lease` so concurrent pushes can't be silently overwritten.
