#!/bin/bash

################################################################################
# Uninstall On-Air LaunchAgent
################################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

DEST_PLIST="$HOME/Library/LaunchAgents/com.user.onair.plist"

echo -e "${BLUE}Uninstalling On-Air${NC}\n"

# Unload service
if launchctl list | grep -q "com.user.onair"; then
    echo -e "${BLUE}Stopping service...${NC}"
    launchctl unload "$DEST_PLIST" 2>/dev/null
    echo -e "${GREEN}✓ Service stopped${NC}"
fi

# Remove plist
if [ -f "$DEST_PLIST" ]; then
    rm "$DEST_PLIST"
    echo -e "${GREEN}✓ LaunchAgent removed${NC}"
fi

echo -e "\n${GREEN}On-Air uninstalled successfully${NC}"
echo -e "${BLUE}The script files in $(dirname $0) are still present${NC}"

