#!/bin/bash

################################################################################
# Install Meeting Listener as LaunchAgent (auto-start on login)
################################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLIST_EXAMPLE="$SCRIPT_DIR/com.user.onair.plist.example"
PLIST_FILE="$SCRIPT_DIR/com.user.onair.plist"
DEST_PLIST="$HOME/Library/LaunchAgents/com.user.onair.plist"

echo -e "${BLUE}Installing On-Air Auto-Start${NC}\n"

# Read webhook URL from ~/.config/onair/config if available
CONFIG_FILE="${HOME}/.config/onair/config"
WEBHOOK_FROM_CONFIG=""
if [[ -f "$CONFIG_FILE" ]]; then
    WEBHOOK_FROM_CONFIG=$(grep -E "^[[:space:]]*HA_WEBHOOK_URL[[:space:]]*=" "$CONFIG_FILE" \
        | tail -1 \
        | sed -E "s/^[[:space:]]*HA_WEBHOOK_URL[[:space:]]*=[[:space:]]*//" \
        | sed "s/^['\"]//; s/['\"]$//")
fi

# Create plist from template if it doesn't exist
if [ ! -f "$PLIST_FILE" ]; then
    if [ ! -f "$PLIST_EXAMPLE" ]; then
        echo -e "${RED}Error: Template file not found: $PLIST_EXAMPLE${NC}"
        exit 1
    fi
    sed -e "s|REPLACE_WITH_INSTALL_PATH|${SCRIPT_DIR}|g" \
        -e "s|REPLACE_WITH_HOME|${HOME}|g" \
        "$PLIST_EXAMPLE" > "$PLIST_FILE"
    echo -e "${GREEN}✓ Created $PLIST_FILE${NC}"
fi

# Auto-populate webhook URL from config file if the plist still has the placeholder
if grep -q "REPLACE_WITH_YOUR_WEBHOOK_URL" "$PLIST_FILE" && [[ -n "$WEBHOOK_FROM_CONFIG" ]]; then
    sed -i '' "s|REPLACE_WITH_YOUR_WEBHOOK_URL|${WEBHOOK_FROM_CONFIG}|g" "$PLIST_FILE"
    echo -e "${GREEN}✓ Webhook URL set from ~/.config/onair/config${NC}"
fi

# Validate
if grep -q "REPLACE_WITH_YOUR_WEBHOOK_URL" "$PLIST_FILE"; then
    echo -e "${RED}Error: Webhook URL not configured.${NC}"
    echo -e "${YELLOW}Set HA_WEBHOOK_URL in ~/.config/onair/config or edit $PLIST_FILE directly, then run ./install.sh again.${NC}"
    exit 1
fi

# Create LaunchAgents directory if needed
mkdir -p "$HOME/Library/LaunchAgents"

# Copy plist and replace placeholders with actual paths
sed -e "s|REPLACE_WITH_INSTALL_PATH|${SCRIPT_DIR}|g" \
    -e "s|REPLACE_WITH_HOME|${HOME}|g" \
    "$PLIST_FILE" > "$DEST_PLIST"
echo -e "${GREEN}✓ Copied LaunchAgent configuration${NC}"

# Unload if already running
if launchctl list | grep -q "com.user.onair"; then
    echo -e "${YELLOW}Stopping existing service...${NC}"
    launchctl unload "$DEST_PLIST" 2>/dev/null
fi

# Load the service
echo -e "${YELLOW}Starting service...${NC}"
if launchctl load "$DEST_PLIST"; then
    echo -e "${GREEN}✓ On-Air installed and started!${NC}\n"
    
    echo -e "${BLUE}Service will now start automatically on login${NC}\n"
    
    echo -e "${BLUE}Useful commands:${NC}"
    echo -e "  Check status:  launchctl list | grep onair"
    echo -e "  View logs:     tail -f ~/Library/Logs/on_air_stdout.log"
    echo -e "  Stop service:  launchctl unload $DEST_PLIST"
    echo -e "  Start service: launchctl load $DEST_PLIST"
    echo -e "  Uninstall:     ./uninstall.sh"
    echo ""
else
    echo -e "${RED}✗ Failed to start service${NC}"
    exit 1
fi

