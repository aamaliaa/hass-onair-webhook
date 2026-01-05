#!/bin/bash

################################################################################
# Google Meet Meeting Listener for Home Assistant
# Monitors Google Meet PWA and sends webhooks to control lights/status
################################################################################

# Configuration
# Note: We detect meetings via Google Chrome tabs, not process names
HA_WEBHOOK="${HA_WEBHOOK_URL:-}"
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
    # Check Google Chrome for meet.google.com tabs to detect meeting status
    local meet_url=$(osascript 2>/dev/null <<'EOF'
        tell application "Google Chrome"
            try
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "meet.google.com" then
                            return URL of t
                        end if
                    end repeat
                end repeat
                return "NO_MEET_TAB"
            on error
                return "ERROR"
            end try
        end tell
EOF
    )
    
    # Check if URL indicates an active meeting
    # Meeting URLs have format: meet.google.com/abc-defg-hij
    # Landing page is: meet.google.com/landing
    if [[ "$meet_url" == "NO_MEET_TAB" ]]; then
        echo "NO_MEET_TAB"
    elif [[ "$meet_url" == "ERROR" ]]; then
        echo "ERROR"
    elif [[ "$meet_url" == *"/landing"* ]] || [[ "$meet_url" == "https://meet.google.com/" ]] || [[ "$meet_url" == "https://meet.google.com" ]]; then
        echo "MEET_HOMEPAGE"
    elif [[ "$meet_url" =~ meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3} ]]; then
        echo "MEET_ACTIVE"
    else
        echo "MEET_UNKNOWN"
    fi
}

# Function to determine if we're in an active meeting
is_active_meeting() {
    local status="$1"
    
    # For PWA: if the app has windows, we're in a meeting
    if [[ "$status" == "MEET_ACTIVE" ]]; then
        return 0  # true - meeting is active
    else
        return 1  # false - no meeting
    fi
}

# Function to send webhook to Home Assistant
send_webhook() {
    local event="$1"    
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
log "INFO" "Starting Google Meet listener..."
log "INFO" "Monitoring Google Chrome for meet.google.com tabs"

# Validate webhook URL is configured
if [[ -z "$HA_WEBHOOK" ]]; then
    echo -e "${RED}Error: HA_WEBHOOK_URL environment variable not set${NC}"
    echo -e "${YELLOW}Please set it before running:${NC}"
    echo -e "  export HA_WEBHOOK_URL='http://homeassistant.local:8123/api/webhook/YOUR_WEBHOOK_ID'"
    echo -e "${YELLOW}Or create a .env file (see .env.example)${NC}"
    exit 1
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
echo -e "${BLUE}Monitoring Google Meet PWA for meeting status changes...${NC}\n"

while true; do
    # Get current meeting status
    MEET_STATUS=$(get_meeting_status)
    
    # Determine current status
    if [[ "$MEET_STATUS" == "NO_MEET_TAB" ]]; then
        CURRENT_STATE="INACTIVE"
        STATUS_TEXT="No Google Meet tab open"
    elif [[ "$MEET_STATUS" == "MEET_HOMEPAGE" ]]; then
        CURRENT_STATE="INACTIVE"
        STATUS_TEXT="Google Meet open (not in meeting)"
    elif [[ "$MEET_STATUS" == "ERROR" ]]; then
        CURRENT_STATE="ERROR"
        STATUS_TEXT="Error checking Google Meet status"
    elif is_active_meeting "$MEET_STATUS"; then
        CURRENT_STATE="ACTIVE"
        STATUS_TEXT="In meeting (detected via URL)"
    else
        CURRENT_STATE="INACTIVE"
        STATUS_TEXT="Google Meet status unclear"
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
    
    sleep "$CHECK_INTERVAL"
done