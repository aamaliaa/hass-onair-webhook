#!/bin/bash
# <swiftbar.title>OnAir Status</swiftbar.title>
# <swiftbar.version>1.0.0</swiftbar.version>
# <swiftbar.author.github>aamaliaa</swiftbar.author.github>
# <swiftbar.desc>Menu bar status for hass-onair-webhook. Shows your meeting state and lets you toggle it.</swiftbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
#
# Installation:
#   1. Install SwiftBar: brew install swiftbar
#   2. Copy (or symlink) this file into your SwiftBar plugins folder:
#        ln -s /path/to/hass-onair-webhook/swiftbar/onair.1s.sh ~/Library/Application\ Support/SwiftBar/Plugins/
#   3. Make sure it's executable: chmod +x onair.1s.sh
#   4. Set ONAIR_SCRIPT_DIR in ~/.config/onair/config (use "Open Configuration…" in the menu)

STATE_FILE="${HOME}/.meeting_listener_state"
CONFIG_FILE="${HOME}/.config/onair/config"

# Absolute path to this script — used for self-invocation by menu item actions.
PLUGIN_SCRIPT="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# ── Parse a single KEY=VALUE from the config file ─────────────────────────────
read_config() {
    local key="$1"
    [[ ! -f "$CONFIG_FILE" ]] && return
    grep -E "^[[:space:]]*${key}[[:space:]]*=" "$CONFIG_FILE" \
        | tail -1 \
        | sed -E "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//" \
        | sed "s/^['\"]//; s/['\"]$//" \
        | sed "s|^~/|${HOME}/|"
}

# ── Locate toggle_meeting.sh ──────────────────────────────────────────────────
find_toggle_script() {
    local candidates=(
        "$(read_config ONAIR_SCRIPT_DIR)/toggle_meeting.sh"
        "${HOME}/.hass-onair-webhook/toggle_meeting.sh"
        "${HOME}/hass-onair-webhook/toggle_meeting.sh"
        "${HOME}/Projects/hass-onair-webhook/toggle_meeting.sh"
        "${HOME}/Developer/hass-onair-webhook/toggle_meeting.sh"
        "$(dirname "$0")/toggle_meeting.sh"  # plugin placed next to the repo
    )
    for p in "${candidates[@]}"; do
        [[ -x "$p" ]] && { echo "$p"; return; }
    done
}

# ── Self-invocation handlers ──────────────────────────────────────────────────
# SwiftBar menu items call this script back with a subcommand argument so that
# actions (toggle, open config) can share config-reading logic with the plugin.

case "${1:-}" in
    --toggle)
        TOGGLE_SCRIPT="$(find_toggle_script)"
        [[ -z "$TOGGLE_SCRIPT" ]] && exit 1
        HA_WEBHOOK_URL="$(read_config HA_WEBHOOK_URL)" \
        HA_BASE_URL="$(read_config HA_BASE_URL)" \
        exec "$TOGGLE_SCRIPT"
        ;;

    --open-config)
        mkdir -p "$(dirname "$CONFIG_FILE")"
        if [[ ! -f "$CONFIG_FILE" ]]; then
            cat > "$CONFIG_FILE" << 'EOF'
# OnAir Menu Bar – configuration
# https://github.com/aamaliaa/hass-onair-webhook
#
# Edit this file and save — the plugin reloads automatically.

# Path to the hass-onair-webhook repo clone (required).
# ONAIR_SCRIPT_DIR=~/hass-onair-webhook

# Home Assistant webhook URL (required).
# Create a webhook automation in HA and paste its URL here.
# HA_WEBHOOK_URL=http://homeassistant.local:8123/api/webhook/YOUR_WEBHOOK_ID

# Home Assistant base URL — used to skip webhooks when away (optional).
# HA_BASE_URL=http://homeassistant.local:8123
EOF
        fi
        open "$CONFIG_FILE"
        exit 0
        ;;
esac

# ── Read current state ────────────────────────────────────────────────────────
# Treat state as UNKNOWN if the file is missing or stale (>30 s), mirroring
# the logic in listener.sh and the native toolbar app.
STATE="UNKNOWN"
if [[ -f "$STATE_FILE" ]]; then
    age=$(( $(date +%s) - $(stat -f %m "$STATE_FILE") ))
    [[ $age -le 30 ]] && STATE=$(tr -d '[:space:]' < "$STATE_FILE")
fi

TOGGLE_SCRIPT="$(find_toggle_script)"

# ── Menu bar icon (first line of output) ─────────────────────────────────────
if [[ -z "$TOGGLE_SCRIPT" ]]; then
    echo "| sfimage=exclamationmark.triangle.fill color=#FF9500"
elif [[ "$STATE" == "ACTIVE" ]]; then
    echo "| sfimage=video.fill color=#FF3B30"
elif [[ "$STATE" == "INACTIVE" ]]; then
    echo "| sfimage=video.slash"
else
    echo "| sfimage=questionmark.circle"
fi

echo "---"

# ── Menu items ────────────────────────────────────────────────────────────────
if [[ -z "$TOGGLE_SCRIPT" ]]; then
    echo "Setup Required | color=#FF9500 disabled=true"
    echo "Set ONAIR_SCRIPT_DIR in the config file below. | disabled=true"
    echo "---"
    echo "Open Configuration… | bash=\"$PLUGIN_SCRIPT\" param1=--open-config terminal=false"
else
    case "$STATE" in
        ACTIVE)   echo "● On Air | color=#FF3B30 disabled=true" ;;
        INACTIVE) echo "○ Not in Meeting | disabled=true" ;;
        *)        echo "? Status Unknown | disabled=true" ;;
    esac
    echo "---"
    echo "Toggle Meeting Status | bash=\"$PLUGIN_SCRIPT\" param1=--toggle terminal=false refresh=true"
    echo "---"
    echo "Open Configuration… | bash=\"$PLUGIN_SCRIPT\" param1=--open-config terminal=false"
fi
