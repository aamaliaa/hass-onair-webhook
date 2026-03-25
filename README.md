# hass-onair-webhook

A macOS tool that monitors Google Meet and Zoom and sends webhooks to Home Assistant when meetings start or end — great for controlling an "on air" light, enabling Do Not Disturb, or triggering any automation.

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
  - [Listener only](#listener-only)
  - [With menu bar app](#with-menu-bar-app)
    - [Option A: Native app](#option-a-native-app)
    - [Option B: SwiftBar plugin](#option-b-swiftbar-plugin)
  - [Configuration](#configuration)
- [Manual Toggle](#manual-toggle)
- [Home Assistant Setup](#home-assistant-setup)
- [Troubleshooting](#troubleshooting)

---

## Requirements

- macOS (tested on Sonoma+)
- Google Chrome with Google Meet and/or the Zoom desktop app
- Home Assistant with a webhook automation

---

## Installation

### Listener only

Just want webhooks with no menu bar UI? This installs `listener.sh` as a LaunchAgent that starts automatically at login.

```bash
git clone <repo-url> && cd hass-onair-webhook
./install.sh
```

To uninstall: `./uninstall.sh`

---

### With menu bar app

The menu bar app shows your on-air status as a camera icon (red when active) and lets you toggle it with a click. Pick one option — both install the listener automatically.

#### Option A: Native app

A native Swift app. Requires the Swift toolchain (`xcode-select --install`). **Does not work on Jamf-managed Macs without code signing.**

```bash
git clone <repo-url> && cd hass-onair-webhook
./install-toolbar.sh
```

#### Option B: SwiftBar plugin

A shell script plugin for [SwiftBar](https://swiftbar.app). Works on managed/Jamf Macs — no code signing or build step required.

```bash
git clone <repo-url> && cd hass-onair-webhook
brew install --cask swiftbar
mkdir -p ~/Library/Application\ Support/SwiftBar/Plugins
ln -s "$(pwd)/swiftbar/onair.1s.sh" \
  ~/Library/Application\ Support/SwiftBar/Plugins/onair.1s.sh
./install.sh
```

Launch SwiftBar and point it at `~/Library/Application Support/SwiftBar/Plugins/` if it asks for a plugins folder.

---

### Configuration

Both menu bar options read `~/.config/onair/config`. Click the icon → **Open Configuration…** to create and edit it:

```ini
# Path to your hass-onair-webhook clone (required)
ONAIR_SCRIPT_DIR=~/hass-onair-webhook

# Home Assistant webhook URL (required)
HA_WEBHOOK_URL=http://homeassistant.local:8123/api/webhook/YOUR_WEBHOOK_ID

# Skip webhooks when HA is unreachable, e.g. when away from home (optional)
# HA_BASE_URL=http://homeassistant.local:8123
```

Save the file — the app reloads automatically. The icon shows an orange warning triangle until `ONAIR_SCRIPT_DIR` is set.

---

## Manual Toggle

For meetings not automatically detected (Teams, phone calls, etc.):

```bash
./toggle_meeting.sh        # toggle on/off
./toggle_meeting.sh on     # force on-air
./toggle_meeting.sh off    # force not-in-meeting
```

---

## Home Assistant Setup

See [`home_assistant_example.yaml`](home_assistant_example.yaml) for a ready-to-use automation.

The webhook payload is a JSON POST to your webhook URL:

```json
{"event": "meet_active",   "timestamp": "2025-10-09T14:30:00Z"}
{"event": "meet_inactive", "timestamp": "2025-10-09T15:30:00Z"}
```

Meeting titles are intentionally omitted for privacy.

---

## Troubleshooting

**macOS permissions:** Grant your terminal app Accessibility access in System Settings → Privacy & Security → Accessibility.

**Test your webhook manually:**
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
