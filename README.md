# hass-onair-webhook

A macOS tool that monitors Google Meet and Zoom and sends webhooks to Home Assistant when meetings start or end. Use it to control an "on air" light, enable Do Not Disturb mode, or trigger any automation.

Includes an optional native menu bar app that shows your meeting status and lets you toggle it with a click.

## Requirements

- macOS (tested on Sonoma+)
- Google Chrome with Google Meet and/or the Zoom app
- Home Assistant with a webhook automation

## Quick Start

```bash
git clone <repo-url> && cd hass-onair-webhook
cp .env.example .env
# Edit .env with your Home Assistant webhook URL
./run.sh          # test manually
./install.sh      # install as a LaunchAgent (auto-starts on login)
```

To uninstall: `./uninstall.sh`

## Menu Bar App (optional)

A native macOS menu bar app that shows your on-air status as a camera icon and lets you toggle it with a click. Requires Xcode or the Swift toolchain.

**Install:**
```bash
./install-toolbar.sh
```

**Configure** — press **Cmd+,** (or click the icon → "Open Configuration") to open `~/.config/onair/config`:

```ini
# Path to your hass-onair-webhook clone
ONAIR_SCRIPT_DIR=~/hass-onair-webhook

# Home Assistant webhook URL
HA_WEBHOOK_URL=http://homeassistant.local:8123/api/webhook/YOUR_WEBHOOK_ID

# Optional: skip webhooks when HA is unreachable (e.g. away from home)
# HA_BASE_URL=http://homeassistant.local:8123
```

Save the file — the app reloads automatically. If `ONAIR_SCRIPT_DIR` isn't set yet, the icon shows an orange warning triangle until you do.

The icon turns **red** when you're on-air and **grey** when you're not. It updates within ~1 second of any state change from `listener.sh`.

> **Cmd+,** — Open Configuration
> **Cmd+R** — Reload Configuration (manual re-read)

## Manual Toggle

For meetings not automatically detected (Teams, phone calls, etc.):

```bash
./toggle_meeting.sh        # toggle between on/off
./toggle_meeting.sh on     # force on-air
./toggle_meeting.sh off    # force not-in-meeting
```

## Home Assistant Setup

See [`home_assistant_example.yaml`](home_assistant_example.yaml) for a ready-to-use automation.

### Webhook Payload

The script sends a JSON POST to your webhook URL:

```json
{"event": "meet_active",   "timestamp": "2025-10-09T14:30:00Z"}
{"event": "meet_inactive", "timestamp": "2025-10-09T15:30:00Z"}
```

Meeting titles are intentionally omitted for privacy.

## Troubleshooting

**macOS permissions:** Grant your terminal app accessibility access in System Settings > Privacy & Security > Accessibility.

**Test webhook manually:**
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"event":"meet_active","timestamp":"2025-01-01T12:00:00Z"}' \
  http://YOUR_HA_IP:8123/api/webhook/YOUR_WEBHOOK_ID
```

**View logs:**
```bash
tail -f ~/Library/Logs/on_air_stdout.log
```

## License

[MIT](LICENSE)
