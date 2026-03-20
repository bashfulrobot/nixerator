# Manual Slack Token Extraction (Chrome)

## Get the xoxc- token

### Option A: Console (localStorage)

1. Open Chrome and go to your Slack workspace (https://app.slack.com)
2. Open DevTools: F12 or Ctrl+Shift+I
3. Go to the Console tab
4. Paste this and press Enter:

   ```javascript
   var c = JSON.parse(localStorage.localConfig_v2);
   console.warn("TOKEN:", c.teams[c.lastActiveTeamId].token);
   ```

   The token prints as a yellow warning so it stands out from Slack's own console noise.

5. Copy the `xoxc-...` value

**Fallback — dump all workspace tokens:**

```javascript
var c = JSON.parse(localStorage.localConfig_v2);
Object.entries(c.teams).forEach(([id, t]) => console.warn(id, t.token));
```

### Option B: Network tab (no JS needed)

1. Open DevTools → Network tab
2. Filter by `api/` and reload the page (or just use Slack normally)
3. Click any `api.slack.com` request
4. In the request headers, find `Authorization: Bearer xoxc-...`
5. Copy the `xoxc-...` value

### Troubleshooting

If `localConfig_v2` is undefined, make sure you're on **app.slack.com** (not a
direct workspace URL) and fully logged in. Try refreshing the page first.

## Get the xoxd- cookie

1. In DevTools, go to Application tab
2. In the sidebar: Storage > Cookies > https://app.slack.com
3. Find the cookie named `d`
4. Copy its Value (starts with `xoxd-`)

## Workspace URL

Your workspace URL looks like: `https://yourteam.slack.com`
