#!/bin/bash

################################################################################
# Install OnAir Menu Bar toolbar app
# Builds the Swift package and creates an .app bundle in ~/Applications
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLBAR_DIR="${SCRIPT_DIR}/toolbar-app"
APP_NAME="OnAirMenuBar"
BUILD_DIR="${TOOLBAR_DIR}/.build/release"
APP_DEST="${HOME}/Applications/${APP_NAME}.app"

# ── Prerequisites ─────────────────────────────────────────────────────────────

if ! command -v swift &>/dev/null; then
    echo "Error: Swift not found."
    echo "Install Xcode from the App Store, or the Swift toolchain from https://swift.org/download/"
    exit 1
fi

# ── Build ─────────────────────────────────────────────────────────────────────

echo "Building ${APP_NAME} (this may take a moment on first run)..."
(cd "${TOOLBAR_DIR}" && swift build -c release 2>&1)
echo "Build complete."

# ── Bundle ────────────────────────────────────────────────────────────────────

echo "Creating app bundle at ${APP_DEST}..."
rm -rf "${APP_DEST}"
mkdir -p "${APP_DEST}/Contents/MacOS"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_DEST}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_DEST}/Contents/MacOS/${APP_NAME}"

cp "${TOOLBAR_DIR}/Sources/OnAirMenuBar/Resources/Info.plist" "${APP_DEST}/Contents/Info.plist"

echo "Installed to ${APP_DEST}"
echo ""

# ── Persist ONAIR_SCRIPT_DIR ──────────────────────────────────────────────────

ENV_FILE="${SCRIPT_DIR}/.env"
if [[ -f "$ENV_FILE" ]] && ! grep -q "ONAIR_SCRIPT_DIR" "$ENV_FILE"; then
    echo "ONAIR_SCRIPT_DIR=${SCRIPT_DIR}" >> "$ENV_FILE"
    echo "Added ONAIR_SCRIPT_DIR to .env so the toolbar can locate toggle_meeting.sh."
elif [[ ! -f "$ENV_FILE" ]]; then
    echo "Note: No .env file found. The toolbar will search common locations for"
    echo "toggle_meeting.sh. Set ONAIR_SCRIPT_DIR=${SCRIPT_DIR} in your .env to"
    echo "point it at this repo explicitly."
fi

echo ""

# ── Launch ────────────────────────────────────────────────────────────────────

read -r -p "Launch the app now? [y/N] " reply
echo
if [[ "$reply" =~ ^[Yy]$ ]]; then
    # Pass ONAIR_SCRIPT_DIR for this first launch so the app can locate scripts
    # even before the user opens a new shell session
    ONAIR_SCRIPT_DIR="${SCRIPT_DIR}" open "${APP_DEST}"
    echo "OnAir Menu Bar is running. Look for the camera icon in your menu bar."
fi
