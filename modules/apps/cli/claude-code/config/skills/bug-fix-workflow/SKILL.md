---
name: bug-fix-workflow
description: >-
  Reproduce a defect as a failing test before fixing it. Use for any bug, crash,
  hang, race, regression, wrong output, exception, stack trace, or flaky test;
  when the user says fix this, debug this, it's broken, or pastes an error; and
  before editing any code in response to a reported symptom. Names the one narrow
  exception where a test is not required.
allowed-tools: ["Read", "Edit", "Write", "Bash", "Grep", "Glob"]
---

# Bug Fixes

- **Reproduce as a failing test before fixing.** For any defect with observable symptoms (wrong output, crash, hang, race), write a test that asserts the *correct* behaviour, confirm it fails with the reported symptom, then fix. If the failure looks different from the report, the test is wrong — fix the test first. Skip only for one-line typos with no realistic test target (e.g. a bad CSS variable name in a single template).
