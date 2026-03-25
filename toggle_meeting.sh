#!/bin/bash

################################################################################
# Manual Meeting Toggle
# Use this to manually trigger meeting status for non-Google Meet meetings
# (Zoom, Teams, phone calls, etc.)
################################################################################

# Configuration (must match listener.sh)
STATE_FILE="${HOME}/.meeting_listener_state"

# Auto-load .env if env vars not set (allows calling from toolbar app or cron)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$HA_WEBHOOK_URL" ]] && [[ -f "${SCRIPT_DIR}/.env" ]]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/.env"
fi
if [[ -z "$HA_WEBHOOK_URL" ]] && [[ -f "${HOME}/.config/onair/config" ]]; then
    # shellcheck source=/dev/null
    source "${HOME}/.config/onair/config"
fi

HA_WEBHOOK="${HA_WEBHOOK_URL:-}"
HA_BASE="${HA_BASE_URL:-}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if Home Assistant is reachable
is_home() {
    if [[ -z "$HA_BASE" ]]; then
        return 0
    fi
    curl -s --max-time 2 "${HA_BASE}/api/" -o /dev/null 2>/dev/null
}

# Function to send webhook
send_webhook() {
    local event="$1"

    if ! is_home; then
        echo -e "${RED}✗ Home Assistant not reachable at ${HA_BASE}${NC}"
        return 1
    fi

    local payload="{\"event\":\"${event}\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$HA_WEBHOOK" 2>&1)
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" == "200" ]]; then
        return 0
    else
        echo -e "${RED}✗ Webhook failed (HTTP ${http_code})${NC}"
        return 1
    fi
}

# Validate webhook URL
if [[ -z "$HA_WEBHOOK" ]]; then
    echo -e "${RED}Error: HA_WEBHOOK_URL environment variable not set${NC}"
    echo -e "${YELLOW}Set it with: export HA_WEBHOOK_URL='http://homeassistant.local:8123/api/webhook/YOUR_WEBHOOK_ID'${NC}"
    exit 1
fi

# Read current state
if [[ -f "$STATE_FILE" ]]; then
    CURRENT_STATE=$(cat "$STATE_FILE")
else
    CURRENT_STATE="INACTIVE"
fi

# Optional argument: "on" forces ACTIVE, "off" forces INACTIVE, default toggles
case "${1:-}" in
    on)  CURRENT_STATE="INACTIVE" ;;  # force the "turn on" path
    off) CURRENT_STATE="ACTIVE"   ;;  # force the "turn off" path
esac

# Toggle state
if [[ "$CURRENT_STATE" == "ACTIVE" ]]; then
    # Turn OFF
    echo -e "${BLUE}Current state: ACTIVE${NC}"
    echo -e "${YELLOW}Switching to: INACTIVE${NC}"
    
    if send_webhook "meet_inactive"; then
        echo "INACTIVE" > "$STATE_FILE"
        echo -e "${GREEN}✓ Meeting status: OFF (lights should turn off)${NC}"
    fi
else
    # Turn ON
    echo -e "${BLUE}Current state: INACTIVE${NC}"
    echo -e "${YELLOW}Switching to: ACTIVE${NC}"
    
    if send_webhook "meet_active"; then
        echo "ACTIVE" > "$STATE_FILE"
        echo -e "${RED}✓ Meeting status: ON (lights should turn red)${NC}"
    fi
fi

echo ""
echo -e "${BLUE}Tip: Run this script again to toggle back${NC}"
echo -e "${BLUE}Webhook URL: ${HA_WEBHOOK}${NC}"

