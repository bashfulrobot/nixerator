// Reads and writes ~/.config/slack/credentials.json.
//
// Separate from extract.mjs so it can be tested without Playwright, and because
// the rules for handling a file full of session tokens are worth stating in one
// place rather than inlining next to browser automation.
//
// Shape: {workspaces: {<name>: {xoxc, xoxd, url, updated}}}. Consumers read this
// file directly, so the two things it owes them are that it is never half-written
// and never wider than 0600.

import {
  readFileSync,
  writeFileSync,
  mkdirSync,
  openSync,
  closeSync,
  fsyncSync,
  renameSync,
  unlinkSync,
} from "fs";
import { homedir } from "os";
import { join } from "path";

// xdgConfig resolves the config root. Injectable so tests never go near the real
// credentials file.
export function xdgConfig(root) {
  if (root) return root;
  return process.env.XDG_CONFIG_HOME || join(homedir(), ".config");
}

export function slackConfigDir(root) {
  return join(xdgConfig(root), "slack");
}

export function credentialsPath(root) {
  return join(slackConfigDir(root), "credentials.json");
}

// readCredentials returns the parsed file, or an empty set on a first run.
//
// It distinguishes "not there yet" from "there but unreadable", which the caller
// depends on completely: the first is normal, and the second must never be
// treated as a blank slate.
function readCredentials(path) {
  let raw;
  try {
    raw = readFileSync(path, "utf-8");
  } catch (err) {
    if (err.code === "ENOENT") return { workspaces: {} };
    throw new Error(`slack-token-refresh: cannot read ${path}: ${err.message}`);
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    // Refuse rather than reset. This file holds every workspace's tokens, and
    // overwriting it with just the one being refreshed silently destroys the
    // rest -- which is exactly what the old empty `catch {}` did. Nothing here
    // can recover them, so the only honest move is to stop and say so.
    throw new Error(
      `slack-token-refresh: refusing to overwrite ${path}: it exists but could not be read (${err.message}). ` +
        `It holds credentials for every workspace, and rewriting it would discard them. ` +
        `Move it aside to start fresh.`,
    );
  }

  if (!parsed || typeof parsed !== "object" || typeof parsed.workspaces !== "object" || parsed.workspaces === null) {
    throw new Error(`slack-token-refresh: refusing to overwrite ${path}: it is not a credentials file. Move it aside to start fresh.`);
  }
  return parsed;
}

// saveCredentials records one workspace's tokens, preserving the others.
//
// The write is atomic: a temp file in the same directory, created 0600, then
// renamed over the target. rename(2) within a filesystem is atomic, so a
// concurrent reader sees either the whole old file or the whole new one and
// never a half of either.
//
// This matters more than it looks. The previous version wrote straight at the
// target with writeFileSync, so a reader could catch a truncated file; that
// presents to a consumer as a broken credential, which sends it off to relaunch
// Chrome to fix a file that was already fine a millisecond later. Worse, this
// function's own reader treated an unparseable file as an empty one, so a torn
// read could destroy every other workspace. The two bugs fed each other.
//
// Creating the temp at 0600 also closes a smaller hole: writeFileSync creates
// with 0666 & ~umask (0644 on a default umask) and the old code chmod'ed on the
// next line, leaving a window where the tokens were world-readable.
//
// root overrides the config root and exists for tests; production omits it.
export function saveCredentials(workspace, xoxc, xoxd, url, root) {
  const dir = slackConfigDir(root);
  const path = credentialsPath(root);

  mkdirSync(dir, { recursive: true, mode: 0o700 });

  const creds = readCredentials(path);
  creds.workspaces[workspace] = {
    xoxc,
    xoxd,
    url,
    updated: new Date().toISOString(),
  };

  // Serialise before touching the filesystem: a stringify failure then throws
  // with no temp file created and the real file untouched.
  const body = JSON.stringify(creds, null, 2) + "\n";

  // Same directory as the target: rename is only atomic within a filesystem, and
  // a temp in /tmp can land on a different one.
  const tmp = join(dir, `.credentials.json.${process.pid}.tmp`);

  // wx fails if the temp somehow exists rather than clobbering it.
  const fd = openSync(tmp, "wx", 0o600);
  try {
    writeFileSync(fd, body);
    fsyncSync(fd);
  } catch (err) {
    closeSync(fd);
    safeUnlink(tmp);
    throw err;
  }
  closeSync(fd);

  try {
    renameSync(tmp, path);
  } catch (err) {
    safeUnlink(tmp);
    throw err;
  }
}

// safeUnlink removes a temp file without masking the error that got us here. A
// leftover temp is a second copy of the tokens at a path nobody audits, so it is
// worth trying, but never worth replacing the real failure with.
function safeUnlink(path) {
  try {
    unlinkSync(path);
  } catch {}
}
