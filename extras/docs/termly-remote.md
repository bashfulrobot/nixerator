# Termly Remote Trigger - iPhone Shortcuts

Control termly sessions from your iPhone over Tailscale. The trigger server runs on port 9735 and exposes a simple JSON API.

## Prerequisites

- Tailscale installed and connected on your iPhone
- The host running termly-trigger (e.g. qbert at `100.74.137.95`)

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/directories` | List available project directories |
| GET | `/status` | Check if termly is running and where |
| POST | `/start?dir=<index or name>` | Start termly in a directory |
| POST | `/stop` | Stop the running termly session |

The `dir` parameter accepts either a numeric index (from `/directories`) or a directory basename like `nixerator`.

## Shortcut 1: Start Termly

Create a new Shortcut with these actions:

1. **URL**: `http://100.74.137.95:9735/directories`
2. **Get Contents of URL** (method: GET)
3. **Get Dictionary Value** for key `directories` from Contents of URL
4. **Repeat with Each** item in Dictionary Value:
   - **Get Dictionary Value** for key `name` from Repeat Item
   - **Add to Variable** `dirNames`
5. **Choose from List**: `dirNames`
6. **URL**: `http://100.74.137.95:9735/start?dir=` + Chosen Item
7. **Get Contents of URL** (method: POST)
8. **Get Dictionary Value** for key `directory` from Contents of URL
9. **Show Notification**: "Termly started in" + Dictionary Value

Alternatively, a simpler version if you mostly use the same few projects:

1. **Choose from Menu**: nixerator, hyprflake, meetsum, etc.
2. For each menu item:
   - **URL**: `http://100.74.137.95:9735/start?dir=<name>`
   - **Get Contents of URL** (method: POST)
3. **Show Notification**: "Termly started"

## Shortcut 2: Stop Termly

1. **URL**: `http://100.74.137.95:9735/stop`
2. **Get Contents of URL** (method: POST)
3. **Get Dictionary Value** for key `was_running` from Contents of URL
4. **If** was_running equals true:
   - **Show Notification**: "Termly stopped"
5. **Otherwise**:
   - **Show Notification**: "Termly was not running"

## Shortcut 3: Termly Status (optional)

1. **URL**: `http://100.74.137.95:9735/status`
2. **Get Contents of URL** (method: GET)
3. **Get Dictionary Value** for key `running` from Contents of URL
4. **If** running equals true:
   - **Get Dictionary Value** for key `directory` from Contents of URL step
   - **Show Notification**: "Termly running in" + Dictionary Value
5. **Otherwise**:
   - **Show Notification**: "Termly is not running"

## Multiple Hosts

If you run termly-trigger on more than one machine (e.g. qbert and donkeykong), you can either:

- Create separate shortcuts per host
- Add a "Choose from Menu" at the top of each shortcut to pick the host IP first, then use that as a variable in the URL

Tailscale IPs:

| Host | IP |
|------|-----|
| qbert | 100.74.137.95 |
| donkeykong | 100.117.210.113 |

## Troubleshooting

Check the trigger service: `systemctl --user status termly-trigger`

Check termly logs: `journalctl --user -u termly -n 20`

Verify connectivity from your phone by opening `http://<tailscale-ip>:9735/status` in Safari. You should see a JSON response.
