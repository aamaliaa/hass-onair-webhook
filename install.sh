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

# Check if user has configured their plist
if [ ! -f "$PLIST_FILE" ]; then
    echo -e "${YELLOW}No configuration found. Creating from template...${NC}"
    if [ ! -f "$PLIST_EXAMPLE" ]; then
        echo -e "${RED}Error: Template file not found: $PLIST_EXAMPLE${NC}"
        exit 1
    fi
    # Create plist from template with paths already substituted
    sed -e "s|REPLACE_WITH_INSTALL_PATH|${SCRIPT_DIR}|g" \
        -e "s|REPLACE_WITH_HOME|${HOME}|g" \
        "$PLIST_EXAMPLE" > "$PLIST_FILE"
    echo -e "${GREEN}✓ Created configuration file: $PLIST_FILE${NC}"
    echo -e "${YELLOW}⚠ Please edit $PLIST_FILE and set your webhook URL${NC}"
    echo -e "${YELLOW}  Change: REPLACE_WITH_YOUR_WEBHOOK_URL${NC}"
    echo -e "${YELLOW}  To: http://homeassistant.local:8123/api/webhook/YOUR_WEBHOOK_ID${NC}"
    echo -e "\n${BLUE}Then run ./install.sh again${NC}"
    exit 1
fi

# Validate the plist has been configured
if grep -q "REPLACE_WITH_YOUR_WEBHOOK_URL" "$PLIST_FILE"; then
    echo -e "${RED}Error: Please configure $PLIST_FILE first${NC}"
    echo -e "${YELLOW}Replace REPLACE_WITH_YOUR_WEBHOOK_URL with your actual webhook URL${NC}"
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

