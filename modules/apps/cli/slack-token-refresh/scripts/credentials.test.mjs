// Tests for the credential file writer.
//
// This logic lives apart from extract.mjs so it can be tested at all: extract.mjs
// imports playwright-core at module scope, and a test that needs a browser to
// check a file write is a test nobody runs.
//
// Run: node --test scripts/

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, statSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";

import { saveCredentials, credentialsPath } from "./credentials.mjs";

// Each test gets its own XDG root so nothing touches the real credentials.
function sandbox() {
  const root = mkdtempSync(join(tmpdir(), "slack-creds-"));
  return { root, path: credentialsPath(root) };
}

function read(path) {
  return JSON.parse(readFileSync(path, "utf-8"));
}

test("writes the workspace on a first run", () => {
  const { root, path } = sandbox();
  saveCredentials("kongstrong", "xoxc-1", "xoxd-1", "https://k.slack.com/", root);

  const got = read(path);
  assert.equal(got.workspaces.kongstrong.xoxc, "xoxc-1");
  assert.equal(got.workspaces.kongstrong.xoxd, "xoxd-1");
  assert.ok(got.workspaces.kongstrong.updated, "updated stamp is the credential's version; it must be set");
});

// The test with teeth: atomicity, checked at the mechanism.
//
// A rename replaces the target with a different file, so the inode changes. A
// writeFileSync truncates the existing file in place, so the inode stays. That
// makes "was this written atomically" directly observable and deterministic,
// with no concurrency and no timing.
//
// This is the one that fails against the old implementation. It is worth knowing
// that the obvious tests -- final mode, "a failed write left the file alone", "no
// temp files remain" -- all PASS against the old code, because the old code
// chmod'ed on the next line, never got far enough to damage anything in the
// simulated failure, and never made temp files to leave behind. Only the inode
// separates truncate-in-place from replace.
test("replaces the file rather than truncating it in place", () => {
  const { root, path } = sandbox();
  saveCredentials("kongstrong", "xoxc-1", "xoxd-1", "https://k.slack.com/", root);
  const first = statSync(path).ino;

  saveCredentials("other", "xoxc-2", "xoxd-2", "https://o.slack.com/", root);
  const second = statSync(path).ino;

  assert.notEqual(
    second,
    first,
    "the file was written in place: a reader that looks mid-write sees a truncated file, " +
      "which presents as a broken credential and sends the consumer off to relaunch Chrome for nothing",
  );
});

// An end-state guard, and honest about being only that. The old code created the
// file 0666 & ~umask (0644 on a default umask) and chmod'ed to 0600 on the next
// line, so the tokens were briefly world-readable. That window is not observable
// after the fact, so this cannot catch it; creating the temp 0600 is what closes
// it. What this does catch is the mode regressing outright.
test("the credentials file ends up no wider than 0600", () => {
  const { root, path } = sandbox();
  saveCredentials("kongstrong", "xoxc-1", "xoxd-1", "https://k.slack.com/", root);

  const mode = statSync(path).mode & 0o777;
  assert.equal(mode.toString(8), "600", `mode was ${mode.toString(8)}; tokens must never be group- or world-readable`);
});

test("preserves workspaces it was not asked to touch", () => {
  const { root, path } = sandbox();
  saveCredentials("kongstrong", "xoxc-1", "xoxd-1", "https://k.slack.com/", root);
  saveCredentials("other", "xoxc-2", "xoxd-2", "https://o.slack.com/", root);

  const got = read(path);
  assert.equal(got.workspaces.kongstrong.xoxc, "xoxc-1", "the first workspace was destroyed by the second write");
  assert.equal(got.workspaces.other.xoxc, "xoxc-2");
});

// The bug this exists for. The old code wrapped the read in `try {} catch {}`
// with an empty handler, so ANY read failure -- including a torn read caused by
// its own non-atomic write -- reset creds to {workspaces:{}} and then wrote only
// the current workspace. Every other workspace was silently deleted. Refusing is
// the only safe move: the tokens it would destroy cannot be recovered from here.
test("refuses to overwrite a credentials file it cannot read", () => {
  const { root, path } = sandbox();
  mkdirSync(join(root, "slack"), { recursive: true });
  writeFileSync(path, '{"workspaces":{"kongstrong":{"xoxc":"xox');

  assert.throws(
    () => saveCredentials("other", "xoxc-2", "xoxd-2", "https://o.slack.com/", root),
    /could not be read|refusing/i,
    "an unreadable file must stop the write, not license clobbering it",
  );

  assert.equal(
    readFileSync(path, "utf-8"),
    '{"workspaces":{"kongstrong":{"xoxc":"xox',
    "the unreadable file must be left exactly as found",
  );
});

// A missing file is the legitimate first run and must not be confused with an
// unreadable one. This is why the catch cannot simply be deleted.
test("a missing file is a first run, not a failure", () => {
  const { root } = sandbox();
  assert.doesNotThrow(() => saveCredentials("kongstrong", "x", "y", "z", root));
});

// Guards the new implementation's failure path, not the old bug: serialising
// before touching the filesystem means a stringify failure cannot reach the real
// file. (The old code passed this too, by luck -- stringify was an argument to
// writeFileSync, so it also threw before the write. Kept because the new code
// could regress here and the old code could not.)
test("a failed write leaves the previous credentials intact", () => {
  const { root, path } = sandbox();
  saveCredentials("kongstrong", "xoxc-1", "xoxd-1", "https://k.slack.com/", root);
  const before = readFileSync(path, "utf-8");

  assert.throws(() => saveCredentials("other", 1n, "xoxd-2", "https://o.slack.com/", root));

  assert.equal(readFileSync(path, "utf-8"), before, "a failed write truncated the real file");
  assert.equal(read(path).workspaces.kongstrong.xoxc, "xoxc-1");
});

// Only meaningful for the new implementation, which is the only one that makes
// temp files. A leftover temp is a second copy of the tokens at a path nobody
// audits, so the cleanup path is worth pinning.
test("leaves no temporary files behind, on success or on failure", () => {
  const { root } = sandbox();
  const dir = join(root, "slack");

  saveCredentials("kongstrong", "xoxc-1", "xoxd-1", "https://k.slack.com/", root);
  assert.deepEqual(readdirSync(dir), ["credentials.json"]);

  assert.throws(() => saveCredentials("other", 1n, "xoxd-2", "https://o.slack.com/", root));
  assert.deepEqual(readdirSync(dir), ["credentials.json"], "a failed write left a temp file holding tokens");
});
