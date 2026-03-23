# Termly Remote Trigger - iPhone Shortcuts

Control termly sessions from your iPhone over Tailscale. The trigger server runs on port 9735 and exposes a simple JSON API.

## Prerequisites

- Tailscale installed and connected on your iPhone
- The host running termly-trigger (e.g. qbert at `100.74.137.95`)
- Verify connectivity: open `http://<tailscale-ip>:9735/status` in Safari and confirm you see JSON

## API Reference

| Method | Path                         | Description                          |
| ------ | ---------------------------- | ------------------------------------ |
| GET    | `/directories`               | List available project directories   |
| GET    | `/status`                    | Check if termly is running and where |
| POST   | `/start?dir=<index or name>` | Start termly in a directory          |
| POST   | `/stop`                      | Stop the running termly session      |

The `dir` parameter accepts either a numeric index (from `/directories`) or a directory basename like `nixerator`.

## Creating the Shortcuts

Open the Shortcuts app on your iPhone. Tap **+** to create a new shortcut for each one below.

### Shortcut 1: Start Termly

This shortcut fetches available directories, lets you pick one, then starts a session.

1. **URL** -- type `http://100.74.137.95:9735/directories`
2. **Get Contents of URL** -- leave defaults (GET)
3. **Get Dictionary Value** -- key: `directories`, from: _Contents of URL_
4. **Repeat with Each** -- select _Dictionary Value_ as the input
   - Inside the loop, add **Get Dictionary Value** -- key: `name`, from: _Repeat Item_
   - Add **Add to Variable** -- variable name: `dirNames`
5. After the loop, add **Choose from List** -- select the `dirNames` variable
6. **URL** -- type `http://100.74.137.95:9735/start?dir=` then tap the variable button and insert _Chosen Item_
7. **Get Contents of URL** -- tap the action, change Method to **POST**
8. **Get Dictionary Value** -- key: `directory`, from: _Contents of URL_
9. **Show Notification** -- title: "Termly started", body: tap variable button and insert _Dictionary Value_

**Simpler alternative** if you always use the same projects:

1. **Choose from Menu** -- add items: `nixerator`, `hyprflake`, `meetsum` (or whatever you use)
2. Under each menu item, add:
   - **URL**: `http://100.74.137.95:9735/start?dir=<name>` (replace `<name>` with the menu item)
   - **Get Contents of URL** -- method: **POST**
3. After the menu block, add **Show Notification**: "Termly started"

### Shortcut 2: Stop Termly

1. **URL** -- type `http://100.74.137.95:9735/stop`
2. **Get Contents of URL** -- method: **POST**
3. **Get Dictionary Value** -- key: `was_running`, from: _Contents of URL_
4. **If** -- _Dictionary Value_ **is** `true`
   - **Show Notification**: "Termly stopped"
5. **Otherwise**
   - **Show Notification**: "Termly was not running"

### Shortcut 3: Termly Status (optional)

1. **URL** -- type `http://100.74.137.95:9735/status`
2. **Get Contents of URL** -- leave defaults (GET)
3. **Get Dictionary Value** -- key: `running`, from: _Contents of URL_
4. **If** -- _Dictionary Value_ **is** `true`
   - **Get Dictionary Value** -- key: `directory`, from: the _Contents of URL_ step (not the If block)
   - **Show Notification**: "Termly running in " + _Dictionary Value_
5. **Otherwise**
   - **Show Notification**: "Termly is not running"

## Tips

- Add shortcuts to your Home Screen: long-press the shortcut, tap _Add to Home Screen_
- Siri works too: name the shortcut "Start Termly" and say "Hey Siri, Start Termly"
- If a session is already running, `/start` returns a 409 conflict. Stop first, then start in the new directory.

## Multiple Hosts

If you run termly-trigger on more than one machine, either:

- Create separate shortcuts per host
- Add a **Choose from Menu** at the top of each shortcut to pick the host, then use that as a variable in the URL

Tailscale IPs:

| Host       | IP              |
| ---------- | --------------- |
| qbert      | 100.74.137.95   |
| donkeykong | 100.117.210.113 |

## Troubleshooting

Check the trigger service: `systemctl --user status termly-trigger`

Check termly logs: `journalctl --user -u termly -n 20`

Verify connectivity from your phone by opening `http://<tailscale-ip>:9735/status` in Safari. You should see a JSON response like `{"running":false,"directory":""}`.
