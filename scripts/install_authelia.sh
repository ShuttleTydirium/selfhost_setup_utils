#!/bin/ash

# install_authelia.sh: A script to install or update Authelia on Alpine Linux (arm64-musl)
# Usage: Run this script with root privileges

# Variables
INSTALL_DIR="/usr/bin"
TEMP_DIR="/tmp/authelia_install"
ARCH="linux-arm64-musl"
REQUIRED_PACKAGES="ca-certificates tzdata"
GITHUB_URL="https://github.com/authelia/authelia/releases"
INIT_SCRIPT_URL="https://raw.githubusercontent.com/ShuttleTydirium/selfhost_setup_utils/main/authelia.rc"
INIT_SCRIPT_NAME="authelia"
USER="authelia"
GROUP="authelia"
HOMEDIR="/var/lib/authelia"
CURRENT_VERSION=""
LATEST_VERSION=""
PACKAGE_NAME=""
DOWNLOAD_URL=""
CHECKSUM_URL=""

# Function to print status messages
log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1" >&2; }

# Check if Authelia is installed
is_authelia_installed() {
  command -v authelia >/dev/null 2>&1
}

# Get the currently installed version of Authelia
get_current_version() {
  if is_authelia_installed; then
    CURRENT_VERSION=$(authelia --version | awk '{print $NF}')
    log_info "Current version: $CURRENT_VERSION"
  else
    log_info "Authelia is not currently installed."
  fi
}

# Get the latest version available on GitHub
get_latest_version() {
  LATEST_VERSION=$(wget -qO- "${GITHUB_URL}/latest" | sed -n 's/.*\(v[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | head -n 1)
  if [ -z "$LATEST_VERSION" ]; then
    log_error "Failed to fetch the latest version."
    exit 1
  fi
  log_info "Latest version: $LATEST_VERSION"
}

# Check if the latest version is newer than the current version
needs_update() {
  [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]
}

# Download and verify the latest release
download_and_verify() {
  DOWNLOAD_URL="${GITHUB_URL}/download/${LATEST_VERSION}/authelia-${LATEST_VERSION}-${ARCH}.tar.gz"
  CHECKSUM_URL="${DOWNLOAD_URL}.sha256"

  TEMP_DIR=$(mktemp -dt authelia.XXXXXX) || {
    log_error "Failed to create a temporary directory."
    exit 1
  }

  log_info "Using temporary directory: ${TEMP_DIR}"
  cd "${TEMP_DIR}" || exit 1

  log_info "Downloading Authelia binary and checksum..."
  wget -q "${DOWNLOAD_URL}" || {
    log_error "Failed to download Authelia binary."
    exit 1
  }

  wget -q "${CHECKSUM_URL}" || {
    log_error "Failed to download checksum file."
    exit 1
  }

  PKG_NAME="authelia-${ARCH}.tar.gz"
  mv "authelia-${LATEST_VERSION}-${ARCH}.tar.gz" "${PKG_NAME}" || {
    log_error "Failed to rename the tarball for checksum verification."
    exit 1
  }

  log_info "Verifying checksum..."
  sha256sum -c "$(basename "${CHECKSUM_URL}")" || {
    log_error "Checksum verification failed."
    exit 1
  }
}

# Ensure required packages are installed
install_dependencies() {
  log_info "Installing dependencies..."
  apk add --no-cache ${REQUIRED_PACKAGES} || {
    log_error "Failed to install dependencies."
    exit 1
  }
}

# Install the Authelia binary
install_authelia() {
  log_info "Extracting and installing Authelia..."
  tar -xzf ${PKG_NAME} || {
    log_error "Failed to extract Authelia archive."
    exit 1
  }

  mv authelia-${ARCH} authelia
  chmod +x authelia
  mv authelia "${INSTALL_DIR}/" || {
    log_error "Failed to move Authelia binary to ${INSTALL_DIR}."
    exit 1
  }

  log_info "Authelia installed successfully."
}

# Create user and group for Authelia if they don't exist
create_user_and_group() {
  if ! getent group "$GROUP" >/dev/null 2>&1; then
    log_info "Creating group: $GROUP"
    addgroup -S "$GROUP" || {
      log_error "Failed to create group: $GROUP"
      exit 1
    }
  else
    log_info "Group $GROUP already exists."
  fi

  if ! id "$USER" >/dev/null 2>&1; then
    log_info "Creating user: $USER"
    adduser -S -G "$GROUP" -D -h "$HOMEDIR" -s /sbin/nologin -g "$USER" "$USER" || {
      log_error "Failed to create user: $USER"
      exit 1
    }
    log_info "User $USER created with home directory $HOMEDIR."
  else
    log_info "User $USER already exists."
  fi
}

# Install the OpenRC init script
install_init_script() {
  log_info "Installing OpenRC init script..."
  wget -q -O "/etc/init.d/${INIT_SCRIPT_NAME}" "${INIT_SCRIPT_URL}" || {
    log_error "Failed to download the init script."
    exit 1
  }

  chmod +x "/etc/init.d/${INIT_SCRIPT_NAME}"
  rc-update add "${INIT_SCRIPT_NAME}" default || {
    log_error "Failed to register the init script."
    exit 1
  }

  log_info "OpenRC init script installed and registered successfully."
}

# Cleanup temporary files
cleanup() {
  log_info "Cleaning up temporary files..."
  rm -rf "${TEMP_DIR}"
}

# Main script logic
main() {
  get_current_version
  get_latest_version

  if ! is_authelia_installed; then
    log_info "Authelia is not installed. Proceeding with new installation..."
    install_dependencies
    create_user_and_group
    install_init_script
    download_and_verify
    install_authelia
    cleanup
    log_info "Authelia installed and configured successfully."
  elif needs_update; then
    log_info "Updating to the latest version of Authelia..."
    download_and_verify
    install_authelia
    cleanup
    log_info "Authelia updated to version ${LATEST_VERSION}."
  else
    log_info "Authelia is already up to date (version ${CURRENT_VERSION})."
  fi
}

# Run the script
main
