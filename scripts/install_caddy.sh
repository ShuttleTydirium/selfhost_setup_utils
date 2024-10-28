#!/bin/ash

# install_caddy.sh: Script to install or update Caddy with custom modules on Alpine Linux (arm64)

# Variables
INSTALL_DIR="/usr/sbin"
CADDY_USER="caddy"
CADDY_GROUP="caddy"
INIT_PACKAGE="caddy-openrc"
REQUIRED_PACKAGES="ca-certificates"
CADDY_URL="https://caddyserver.com/api/download?os=linux&arch=arm64&p=github.com%2Fcaddy-dns%2Fporkbun"
GITHUB_RELEASES="https://github.com/caddyserver/caddy/releases"

# Utility functions
log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1"; exit 1; }

# Fetch the installed version, or "none" if not installed
get_current_version() {
  if command -v caddy >/dev/null 2>&1; then
    caddy version | awk '{print $1}'
  else
    echo "none"
  fi
}

# Fetch the latest version using sed
get_latest_version() {
  wget -qO- "${GITHUB_RELEASES}/latest" | \
    sed -n 's/.*tag\/v\([0-9.]*\).*/\1/p' | head -n1
}

# Install necessary dependencies
install_dependencies() {
  log_info "Installing dependencies..."
  apk add --no-cache $REQUIRED_PACKAGES || log_error "Failed to install dependencies."
}

# Create caddy user and groups if not already present
create_user_and_group() {
  log_info "Creating caddy user and group if necessary..."
  addgroup -S -g 82 www-data 2>/dev/null || true
  addgroup -S $CADDY_GROUP 2>/dev/null || true
  adduser -S -D -h /var/lib/caddy -s /sbin/nologin -G $CADDY_GROUP -g $CADDY_USER $CADDY_USER 2>/dev/null || true
  adduser $CADDY_USER www-data 2>/dev/null || true
}

# Install the OpenRC init script for Caddy
install_init_script() {
  log_info "Installing Caddy OpenRC init script..."
  apk add --no-cache $INIT_PACKAGE || log_error "Failed to install Caddy OpenRC package."
  rc-update add caddy default || log_error "Failed to register Caddy with OpenRC."
}

# Download and install Caddy binary
install_caddy_binary() {
  log_info "Downloading Caddy from: $CADDY_URL"
  wget -q -O caddy "$CADDY_URL" || log_error "Failed to download Caddy."
  chmod +x caddy
  mv caddy $INSTALL_DIR/ || log_error "Failed to move Caddy binary to $INSTALL_DIR."
}

# Cleanup function to remove temporary files
cleanup() {
  log_info "Cleaning up..."
  rm -f ./caddy
}

# Main logic
main() {
  current_version=$(get_current_version)
  latest_version=$(get_latest_version)

  log_info "Current version: $current_version"
  log_info "Latest version: $latest_version"

  if [ "$current_version" = "$latest_version" ]; then
    log_info "Caddy is already up to date."
  else
    log_info "Installing or updating Caddy..."
    install_dependencies

    # Only create user/group and install init script if Caddy isn't installed
    if [ "$current_version" = "none" ]; then
      create_user_and_group
      install_init_script
    fi

    install_caddy_binary
    cleanup
    log_info "Caddy installed/updated successfully to version $latest_version."
  fi
}

# Run the main function
main
