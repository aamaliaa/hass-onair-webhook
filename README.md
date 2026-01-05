# hass-onair-webhook

A macOS shell script that monitors Google Meet and sends webhooks to Home Assistant when meetings start or end. Use it to control an "on air" light, enable Do Not Disturb mode, or trigger any automation.

## Requirements

- macOS (tested on Sonoma+)
- Google Chrome with Google Meet
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

## Manual Toggle

For non-Google Meet calls (Zoom, Teams, phone):

```bash
./toggle_meeting.sh
```

Run again to toggle back.

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
