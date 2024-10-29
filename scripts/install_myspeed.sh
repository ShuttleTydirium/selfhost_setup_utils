#!/bin/ash

# Define constants
GROUP="myspeed"
USER="myspeed"
TEMP_DEPS="curl unzip"
ALPINE_VERSION_REQUIRED="3.18"

# Function to report status and progress
report_status() {
    echo "[INFO] $1"
}

# Function to handle errors
handle_error() {
    echo "[ERROR] $1"
    exit 1
}

# Check Alpine version
report_status "Checking Alpine Linux version..."
ALPINE_VERSION=$(cat /etc/alpine-release)
if [ "${ALPINE_VERSION%.*}" != "$ALPINE_VERSION_REQUIRED" ]; then
    handle_error "Unsupported Alpine version: $ALPINE_VERSION. Please use Alpine $ALPINE_VERSION_REQUIRED.x with Node.js v18."
fi
report_status "Alpine version is compatible. Proceeding..."

# Install dependencies
report_status "Installing temporary dependencies: $TEMP_DEPS..."
apk add --no-cache $TEMP_DEPS || handle_error "Failed to install temporary dependencies."

report_status "Installing Node.js and npm..."
apk add --no-cache nodejs npm || handle_error "Failed to install Node.js and npm."

# Download and install myspeed package
report_status "Setting up myspeed installation..."
mkdir -p /opt/myspeed && cd /opt/myspeed || handle_error "Failed to create directory."

DOWNLOAD_URL=$(curl -s https://api.github.com/repos/gnmyt/myspeed/releases/latest | grep browser_download_url | cut -d '"' -f 4)
wget "$DOWNLOAD_URL" || handle_error "Failed to download myspeed package."

unzip MySpeed-*.zip || handle_error "Failed to unzip myspeed package."
rm MySpeed-*.zip || handle_error "Failed to remove zip file."

npm install || handle_error "Failed to install myspeed npm dependencies."

# Cleanup
report_status "Cleaning up temporary dependencies and files..."
apk del $TEMP_DEPS || handle_error "Failed to remove temporary dependencies."
rm -rf /tmp/* || handle_error "Failed to clean /tmp/."

# Create system user and group
report_status "Creating system user and group: $GROUP, $USER..."
addgroup -S "$GROUP" || handle_error "Failed to create group."
adduser -S -G "$GROUP" -D -h /nonexistent -s /sbin/nologin -g "$USER" "$USER" || handle_error "Failed to create user."

# Install and register init script
report_status "Installing and registering myspeed init script..."
INIT_SCRIPT_URL="https://raw.githubusercontent.com/ShuttleTydirium/selfhost_setup_utils/main/scripts/myspeed.rc"
wget -O /etc/init.d/myspeed "$INIT_SCRIPT_URL" || handle_error "Failed to download init script."
chmod +x /etc/init.d/myspeed || handle_error "Failed to make init script executable."

rc-update add myspeed default || handle_error "Failed to register myspeed with OpenRC."

# Final status report
report_status "MySpeed installation completed successfully!"
