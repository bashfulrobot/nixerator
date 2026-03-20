#!/usr/bin/env node
// slack-token-refresh — Extract Slack xoxc/xoxd tokens via Playwright
// Uses a persistent browser profile so you only log in once.
// Subsequent runs can be headless.
//
// Usage:
//   slack-token-refresh [--headless] [workspace-name]
//
// Saves to $XDG_CONFIG_HOME/slack/credentials.json

import { chromium } from "playwright-core";
import { readFileSync, writeFileSync, mkdirSync, chmodSync } from "fs";
import { homedir } from "os";
import { join } from "path";
import { createInterface } from "readline";

const XDG_CONFIG = process.env.XDG_CONFIG_HOME || join(homedir(), ".config");
const SLACK_CONFIG_DIR = join(XDG_CONFIG, "slack");
const CREDENTIALS_FILE = join(SLACK_CONFIG_DIR, "credentials.json");
const PROFILE_DIR = join(SLACK_CONFIG_DIR, "browser-profile");
const SLACK_URL = "https://app.slack.com/client/";

// Chrome path injected at build time by Nix, fallback for dev use
const CHROME_PATH = process.env.CHROME_PATH || "google-chrome-stable";

function prompt(question) {
  const rl = createInterface({ input: process.stdin, output: process.stderr });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

function saveCredentials(workspace, xoxc, xoxd, url) {
  mkdirSync(SLACK_CONFIG_DIR, { recursive: true });
  let creds = { workspaces: {} };
  try {
    creds = JSON.parse(readFileSync(CREDENTIALS_FILE, "utf-8"));
  } catch {}
  creds.workspaces[workspace] = {
    xoxc,
    xoxd,
    url,
    updated: new Date().toISOString(),
  };
  writeFileSync(CREDENTIALS_FILE, JSON.stringify(creds, null, 2) + "\n");
  chmodSync(CREDENTIALS_FILE, 0o600);
}

async function validateToken(xoxc, xoxd) {
  const resp = await fetch("https://slack.com/api/auth.test", {
    headers: {
      Authorization: `Bearer ${xoxc}`,
      Cookie: `d=${xoxd}`,
    },
  });
  return resp.json();
}

async function extractTokens(options = {}) {
  const { headless = false, workspaceName } = options;

  mkdirSync(PROFILE_DIR, { recursive: true });

  console.error(`Launching Chrome (headless=${headless})...`);

  const browser = await chromium.launchPersistentContext(PROFILE_DIR, {
    executablePath: CHROME_PATH,
    headless,
    args: [
      "--disable-blink-features=AutomationControlled",
      "--no-first-run",
      "--no-default-browser-check",
    ],
    viewport: { width: 1280, height: 800 },
  });

  try {
    const page = browser.pages()[0] || (await browser.newPage());

    console.error(`Navigating to Slack...`);
    await page.goto(SLACK_URL);

    try {
      await page.waitForLoadState("networkidle", { timeout: 30000 });
    } catch {}

    // Check if login is needed
    const currentUrl = page.url();
    if (
      currentUrl.includes("signin") ||
      currentUrl.includes("sign_in") ||
      currentUrl.includes("ssb/signin")
    ) {
      if (headless) {
        console.error("Not logged in. Run without --headless first.");
        await browser.close();
        process.exit(1);
      }

      console.error("");
      console.error("Log in to Slack in the browser window.");
      console.error("Press ENTER here when you see your workspace...");
      await prompt("");

      try {
        await page.waitForURL("**/client/**", { timeout: 10000 });
        await page.waitForLoadState("networkidle", { timeout: 30000 });
      } catch {}
    }

    // Extract team ID
    let teamId = null;
    const pathMatch = page.url().match(/\/client\/([A-Z0-9]+)/);
    if (pathMatch) {
      teamId = pathMatch[1];
    } else {
      teamId = await page.evaluate(() => {
        try {
          const cfg = JSON.parse(localStorage.localConfig_v2 || "{}");
          return Object.keys(cfg.teams || {})[0] || null;
        } catch {
          return null;
        }
      });
    }

    if (!teamId) {
      console.error("Could not determine team ID.");
      await browser.close();
      process.exit(1);
    }
    console.error(`Team: ${teamId}`);

    // Extract xoxc token
    let xoxc = await page.evaluate((tid) => {
      try {
        const cfg = JSON.parse(localStorage.localConfig_v2 || "{}");
        if (cfg.teams?.[tid]?.token) return cfg.teams[tid].token;
        for (const data of Object.values(cfg.teams || {})) {
          if (data.token?.startsWith("xoxc-")) return data.token;
        }
      } catch {}
      return null;
    }, teamId);

    if (!xoxc) {
      xoxc = await page.evaluate(() => {
        const m = document.body.innerHTML.match(/"token":"(xoxc-[^"]+)"/);
        return m ? m[1] : null;
      });
    }

    if (!xoxc) {
      console.error("Could not find xoxc token.");
      await browser.close();
      process.exit(1);
    }
    console.error(`Got xoxc token.`);

    // Extract xoxd cookie
    const cookies = await browser.cookies();
    const dCookie = cookies.find(
      (c) => c.name === "d" && c.domain.includes("slack.com")
    );

    if (!dCookie) {
      console.error("Could not find xoxd cookie.");
      await browser.close();
      process.exit(1);
    }
    const xoxd = dCookie.value;
    console.error(`Got xoxd cookie.`);

    // Get team info
    const teamInfo = await page.evaluate((tid) => {
      try {
        const cfg = JSON.parse(localStorage.localConfig_v2 || "{}");
        const team = cfg.teams?.[tid] || {};
        return {
          url: team.url || "",
          domain: team.domain || "",
          name: team.name || "",
        };
      } catch {
        return {};
      }
    }, teamId);

    await browser.close();

    // Validate
    console.error("Validating...");
    const auth = await validateToken(xoxc, xoxd);
    if (!auth.ok) {
      console.error(`Validation failed: ${auth.error}`);
      process.exit(1);
    }

    // Save
    const workspace =
      workspaceName || teamInfo.domain || auth.team || "default";
    const url =
      teamInfo.url || auth.url || `https://${workspace}.slack.com`;
    saveCredentials(workspace, xoxc, xoxd, url);

    console.error(`Authenticated as ${auth.user} in ${auth.team}`);
    console.error(`Saved to ${CREDENTIALS_FILE}`);

    // Machine-readable stdout
    console.log(
      JSON.stringify({
        workspace,
        user: auth.user,
        team: auth.team,
        url,
        updated: new Date().toISOString(),
      })
    );
  } catch (err) {
    await browser.close().catch(() => {});
    throw err;
  }
}

// Parse args
const args = process.argv.slice(2);
const headless = args.includes("--headless");
const workspaceName = args.find((a) => !a.startsWith("--"));

extractTokens({ headless, workspaceName }).catch((err) => {
  console.error(`Error: ${err.message}`);
  process.exit(1);
});
