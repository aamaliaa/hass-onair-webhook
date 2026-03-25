#!/bin/bash

################################################################################
# Meeting Listener for Home Assistant
# Monitors Google Meet and Zoom and sends webhooks to control lights/status
################################################################################

# Configuration
# Note: We detect meetings via Google Chrome tabs, not process names

# Auto-load ~/.config/onair/config if env vars not set
if [[ -z "$HA_WEBHOOK_URL" ]] && [[ -f "${HOME}/.config/onair/config" ]]; then
    # shellcheck source=/dev/null
    source "${HOME}/.config/onair/config"
fi

HA_WEBHOOK="${HA_WEBHOOK_URL:-}"
HA_BASE="${HA_BASE_URL:-}"
CHECK_INTERVAL="${CHECK_INTERVAL:-5}"  # Check every 5 seconds
STATE_FILE="${HOME}/.meeting_listener_state"
LOG_FILE="${LOG_FILE:-/tmp/meeting_listener.log}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Function to get the current meeting status
get_meeting_status() {
    # Check Google Chrome tabs for Google Meet and Zoom
    local chrome_result
    chrome_result=$(osascript 2>/dev/null <<'EOF'
        tell application "Google Chrome"
            try
                repeat with w in windows
                    repeat with t in tabs of w
                        set tabURL to URL of t
                        if tabURL contains "meet.google.com" then
                            return "MEET:" & tabURL
                        end if
                        if tabURL contains "zoom.us/j/" then
                            return "ZOOM_BROWSER"
                        end if
                    end repeat
                end repeat
                return "NO_TAB"
            on error
                return "ERROR"
            end try
        end tell
EOF
    )

    # Handle Google Meet URL
    # Meeting URLs: meet.google.com/abc-defg-hij
    # Landing page:  meet.google.com/landing or root
    if [[ "$chrome_result" == MEET:* ]]; then
        local meet_url="${chrome_result#MEET:}"
        if [[ "$meet_url" == *"/landing"* ]] || [[ "$meet_url" == "https://meet.google.com/" ]] || [[ "$meet_url" == "https://meet.google.com" ]]; then
            echo "MEET_HOMEPAGE"
        elif [[ "$meet_url" =~ meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3} ]]; then
            echo "MEET_ACTIVE"
        else
            echo "MEET_UNKNOWN"
        fi
        return
    fi

    # Zoom meeting open in Chrome
    if [[ "$chrome_result" == "ZOOM_BROWSER" ]]; then
        echo "ZOOM_ACTIVE"
        return
    fi

    # Check native Zoom.app (works even if Chrome is not running)
    if pgrep -xq "zoom.us"; then
        local zoom_wins
        zoom_wins=$(osascript 2>/dev/null <<'EOF'
            tell application "System Events"
                try
                    if exists process "zoom.us" then
                        return count of windows of process "zoom.us"
                    end if
                    return 0
                on error
                    return 0
                end try
            end tell
EOF
        )
        # More than one window = meeting window + home screen
        if [[ "$zoom_wins" =~ ^[0-9]+$ ]] && (( zoom_wins > 1 )); then
            echo "ZOOM_ACTIVE"
            return
        fi
    fi

    if [[ "$chrome_result" == "ERROR" ]]; then
        echo "ERROR"
    else
        echo "NO_MEET_TAB"
    fi
}

# Function to determine if we're in an active meeting
is_active_meeting() {
    local status="$1"
    if [[ "$status" == "MEET_ACTIVE" ]] || [[ "$status" == "ZOOM_ACTIVE" ]]; then
        return 0  # true - meeting is active
    else
        return 1  # false - no meeting
    fi
}

# Check if Home Assistant is reachable on the local network
is_home() {
    if [[ -z "$HA_BASE" ]]; then
        return 0  # No base URL configured, skip check
    fi
    curl -s --max-time 2 "${HA_BASE}/api/" -o /dev/null 2>/dev/null
}

# Function to send webhook to Home Assistant
send_webhook() {
    local event="$1"

    if ! is_home; then
        log "INFO" "Home Assistant not reachable, skipping webhook: event=${event}"
        return 0
    fi

    # Create JSON payload with timestamp only (no sensitive meeting info)
    local payload="{\"event\":\"${event}\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    
    # Send webhook
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$HA_WEBHOOK" 2>&1)
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" == "200" ]]; then
        log "INFO" "Webhook sent successfully: event=${event}"
        return 0
    else
        log "ERROR" "Failed to send webhook. HTTP code: ${http_code}"
        return 1
    fi
}

# Initialize
log "INFO" "Starting meeting listener..."
log "INFO" "Monitoring Google Meet and Zoom for meeting status"

# Validate webhook URL is configured
if [[ -z "$HA_WEBHOOK" ]]; then
    echo -e "${RED}Error: HA_WEBHOOK_URL environment variable not set${NC}"
    echo -e "${YELLOW}Please set it before running:${NC}"
    echo -e "  export HA_WEBHOOK_URL='http://homeassistant.local:8123/api/webhook/YOUR_WEBHOOK_ID'"
    echo -e "${YELLOW}Or create a .env file (see .env.example)${NC}"
    exit 1
fi

if [[ -n "$HA_BASE" ]]; then
    log "INFO" "Home reachability check: ${HA_BASE}"
else
    log "WARN" "HA_BASE_URL not set, skipping reachability check"
fi

log "INFO" "Webhook URL: ${HA_WEBHOOK}"
log "INFO" "Check interval: ${CHECK_INTERVAL}s"

# Load previous state if exists and is recent
if [[ -f "$STATE_FILE" ]]; then
    # Check if state file is fresh (modified within last 30 seconds)
    # If stale, assume state is unknown to avoid false transitions
    STATE_AGE=$(($(date +%s) - $(stat -f %m "$STATE_FILE" 2>/dev/null || echo 0)))
    if [[ $STATE_AGE -lt 30 ]]; then
        LAST_STATE=$(cat "$STATE_FILE")
        log "INFO" "Resuming from previous state: ${LAST_STATE} (${STATE_AGE}s ago)"
    else
        LAST_STATE="UNKNOWN"
        log "INFO" "Previous state is stale (${STATE_AGE}s old), starting fresh"
    fi
else
    LAST_STATE="UNKNOWN"
fi

# Cleanup handler
cleanup() {
    log "INFO" "Shutting down meeting listener..."
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main loop
echo -e "${GREEN}Meeting Listener is running. Press Ctrl+C to stop.${NC}"
echo -e "${BLUE}Monitoring Google Meet and Zoom for meeting status changes...${NC}\n"

while true; do
    # Get current meeting status
    MEET_STATUS=$(get_meeting_status)

    # Determine current status
    if [[ "$MEET_STATUS" == "NO_MEET_TAB" ]]; then
        CURRENT_STATE="INACTIVE"
        STATUS_TEXT="No active meeting detected"
    elif [[ "$MEET_STATUS" == "MEET_HOMEPAGE" ]]; then
        CURRENT_STATE="INACTIVE"
        STATUS_TEXT="Google Meet open (not in meeting)"
    elif [[ "$MEET_STATUS" == "ZOOM_ACTIVE" ]]; then
        CURRENT_STATE="ACTIVE"
        STATUS_TEXT="In Zoom meeting"
    elif [[ "$MEET_STATUS" == "ERROR" ]]; then
        CURRENT_STATE="ERROR"
        STATUS_TEXT="Error checking meeting status"
    elif is_active_meeting "$MEET_STATUS"; then
        CURRENT_STATE="ACTIVE"
        STATUS_TEXT="In Google Meet meeting"
    else
        CURRENT_STATE="INACTIVE"
        STATUS_TEXT="Meeting status unclear"
    fi
    
    # Check if state changed
    if [[ "$CURRENT_STATE" != "$LAST_STATE" ]] && [[ "$CURRENT_STATE" != "ERROR" ]]; then
        # Don't send webhooks if recovering from UNKNOWN state (startup/stale)
        # Just establish baseline silently
        if [[ "$LAST_STATE" == "UNKNOWN" ]]; then
            echo -e "\n${BLUE}Initial state detected: ${CURRENT_STATE}${NC}"
            log "INFO" "Baseline state established: ${CURRENT_STATE} (no webhook sent)"
        else
            echo -e "\n${YELLOW}State changed: ${LAST_STATE} → ${CURRENT_STATE}${NC}"
            log "INFO" "State changed from ${LAST_STATE} to ${CURRENT_STATE}"
            
            if [[ "$CURRENT_STATE" == "ACTIVE" ]]; then
                echo -e "${GREEN}🔴 Meeting STARTED${NC}"
                log "INFO" "Meeting started"
                send_webhook "meet_active"
            else
                echo -e "${RED}🟢 Meeting ENDED${NC}"
                log "INFO" "Meeting ended"
                send_webhook "meet_inactive"
            fi
        fi
        
        # Save new state
        echo "$CURRENT_STATE" > "$STATE_FILE"
        LAST_STATE="$CURRENT_STATE"
    else
        # Just show current status (overwrite line)
        printf "\r${BLUE}Status:${NC} %-80s" "$STATUS_TEXT"
    fi
    
    # Touch the state file every iteration so the toolbar never sees stale state
    # (the 30s staleness window exists to catch listener crashes, not quiet periods)
    [[ "$CURRENT_STATE" != "ERROR" ]] && [[ -f "$STATE_FILE" ]] && touch "$STATE_FILE"

    sleep "$CHECK_INTERVAL"
done