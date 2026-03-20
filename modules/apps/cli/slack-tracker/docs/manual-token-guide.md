# Manual Slack Token Extraction (Chrome)

## Get the xoxc- token

1. Open Chrome and go to your Slack workspace (https://app.slack.com)
2. Open DevTools: F12 or Ctrl+Shift+I
3. Go to the Console tab
4. Paste this and press Enter:

   ```javascript
   JSON.parse(localStorage.localConfig_v2).teams[JSON.parse(localStorage.localConfig_v2).lastActiveTeamId].token
   ```

5. Copy the `xoxc-...` value (without quotes)

## Get the xoxd- cookie

1. In DevTools, go to Application tab
2. In the sidebar: Storage > Cookies > https://app.slack.com
3. Find the cookie named `d`
4. Copy its Value (starts with `xoxd-`)

## Workspace URL

Your workspace URL looks like: `https://yourteam.slack.com`
