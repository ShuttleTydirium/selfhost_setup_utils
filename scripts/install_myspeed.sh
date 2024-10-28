#!/bin/ash

# Global Variables
MAIN_URL="https://raw.githubusercontent.com/ShuttleTydirium/selfhost_setup_utils/main"
NODE_URL="$MAIN_URL/packages/node-v20.18.4-linux-arm64-musl.tar.gz" 
YARN_VERSION="1.22.19"
MYSPEED_URL="$MAIN_URL/packages/myspeed-v109-linux-arm64.tar.gz"
MYSPEED_INIT_URL="$MAIN_URL/scripts/myspeed.rc"

# Exit immediately if a command exits with a non-zero status
set -e

log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1"; exit 1; }
cleanup() { rm -rf /tmp/* /var/cache/apk/* ~/.gnupg/; }

# Step 1: Install Node.js
install_node() {
    log_info "Installing libstdc++ dependency"
    apk add --no-cache libstdc++ curl

    log_info "Downloading Node.js precompiled package"
    curl -fsSL "$NODE_URL" -o /tmp/node.tar.gz

    log_info "Extracting Node.js to /usr/local/"
    tar -xzf /tmp/node.tar.gz -C /usr/local/
    rm /tmp/node.tar.gz

    log_info "Node.js installation complete"
}

# Step 2: Install Yarn
install_yarn() {
    log_info "Installing build dependencies for Yarn"
    apk add --no-cache --virtual .build-deps-yarn curl gnupg tar

    log_info "Setting up GPG keys for Yarn verification"
    export GNUPGHOME="$(mktemp -d)"
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys 6A010C5166006599AA17F08146C2130DFD2497F5 || \
        gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 6A010C5166006599AA17F08146C2130DFD2497F5

    log_info "Downloading Yarn version $YARN_VERSION"
    curl -fsSLO "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz"
    curl -fsSLO "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc"
    gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz

    log_info "Installing Yarn"
    mkdir -p /opt
    tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/
    ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn
    ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg

    log_info "Cleaning up Yarn installation files"
    rm yarn-v$YARN_VERSION.tar.gz*
    gpgconf --kill all
    rm -rf "$GNUPGHOME"
    apk del .build-deps-yarn

    log_info "Yarn installation complete"
}

# Step 3: Install myspeed
install_myspeed() {
    log_info "Installing tzdata dependency"
    apk add --no-cache tzdata

    log_info "Downloading myspeed package"
    curl -fsSL "$MYSPEED_URL" -o /tmp/myspeed.tar.gz

    log_info "Extracting myspeed to /opt/myspeed/"
    mkdir -p /opt/myspeed
    tar -xzf /tmp/myspeed.tar.gz -C /opt/myspeed/
    rm /tmp/myspeed.tar.gz

    log_info "Creating system user and group for myspeed"
    addgroup -S myspeed || log_error "Failed to create group"
    adduser -S -G myspeed -s /sbin/nologin myspeed || log_error "Failed to create user"

    log_info "Downloading and installing myspeed init script"
    curl -fsSL "$MYSPEED_INIT_URL" -o /etc/init.d/myspeed
    chmod +x /etc/init.d/myspeed

    log_info "Registering myspeed service with OpenRC"
    rc-update add myspeed default

    log_info "myspeed installation complete"
}

# Main Installation Flow
main() {
    log_info "Starting myspeed installation process"
    install_node
    install_yarn
    install_myspeed
    cleanup
    log_info "myspeed installed successfully!"
}

# Execute the main function
main
