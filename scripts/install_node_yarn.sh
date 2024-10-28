#!/bin/ash

# Set versions and variables
NODE_VERSION="18.20.4"
YARN_VERSION="1.22.19"
ARCH="arm64"
OPENSSL_ARCH="linux-aarch64"

# Utility functions for status and error handling
log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1" >&2; exit 1; }
cleanup() { apk del .build-deps .build-deps-full .build-deps-yarn && rm -rf /tmp/*; }

# Check if a command succeeded
check_cmd() {
  "$@" || log_error "Command failed: $*"
}

# Step 1: Add node user/group and install dependencies
log_info "Adding node user/group and installing dependencies..."
check_cmd addgroup -g 1000 node
check_cmd adduser -u 1000 -G node -s /bin/sh -D node
check_cmd apk add --no-cache --virtual .build-deps libstdc++ curl

# Step 2: Try downloading a pre-built Node.js binary
log_info "Attempting to download pre-built Node.js binary..."
NODE_TAR="node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz"
CHECKSUM="ac4fe3bef38d5e4ecf172b46c8af1f346904afd9788ce12919e3696f601e191e"

if curl -fsSLO --compressed "https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/$NODE_TAR"; then
  echo "$CHECKSUM  $NODE_TAR" | sha256sum -c - || log_error "Checksum verification failed!"
  tar -xJf "$NODE_TAR" -C /usr/local --strip-components=1 --no-same-owner
  ln -sf /usr/local/bin/node /usr/local/bin/nodejs
  rm -f "$NODE_TAR"
else
  # Step 3: Build Node.js from source if binary is unavailable
  log_info "Pre-built binary unavailable. Building Node.js from source..."
  check_cmd apk add --no-cache --virtual .build-deps-full \
    binutils-gold g++ gcc gnupg libgcc linux-headers make python3 py-setuptools

  export GNUPGHOME="$(mktemp -d)"
  for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    141F07595B7B3FFE74309A937405533BE57C7D57 \
    74F12602B6F1C4E913FAA37AD3A89613643B6201 \
    DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7 \
    61FC681DFB92A079F1685E77973F295594EC4689 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    A363A499291CBBC940DD62E41F10027AF002F8B0 \
    CC68F5A3106FF448322E48ED27F5E38D5B0A215F; do
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"
  done

  curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz"
  curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc"
  gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc
  gpgconf --kill all
  rm -rf "$GNUPGHOME"

  grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - || log_error "Source archive checksum failed!"
  
  tar -xf "node-v$NODE_VERSION.tar.xz"
  cd "node-v$NODE_VERSION"
  ./configure
  make -j$(getconf _NPROCESSORS_ONLN) V= || log_error "Node.js build failed!"
  check_cmd make install
  cd ..
  rm -rf "node-v$NODE_VERSION"*

  # Clean up downloaded files
  rm "node-v$NODE_VERSION.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt || \
    log_error "Failed to remove Node.js build files"

  # Remove musl binary tarball if it exists
  rm -f "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" || \
    log_error "Failed to remove musl binary tarball"

  # Remove unused OpenSSL headers to save space (~34MB)
  find /usr/local/include/node/openssl/archs -mindepth 1 -maxdepth 1 ! -name "$OPENSSL_ARCH" -exec rm -rf {} + || \
    log_error "Failed to clean up unused OpenSSL headers"
fi

# Step 4: Install Yarn
log_info "Installing Yarn..."
check_cmd apk add --no-cache --virtual .build-deps-yarn curl gnupg tar

export GNUPGHOME="$(mktemp -d)"
gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys 6A010C5166006599AA17F08146C2130DFD2497F5 || \
gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 6A010C5166006599AA17F08146C2130DFD2497F5

curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz"
curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc"
gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz || log_error "Yarn verification failed!"
gpgconf --kill all
rm -rf "$GNUPGHOME"
  
mkdir -p /opt
tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/
ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn
ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg
rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz*

# Step 5: Cleanup and final checks
log_info "Cleaning up..."
cleanup

log_info "Installation completed successfully!"
log_info "Node.js version: $(node --version)"
log_info "npm version: $(npm --version)"
log_info "Yarn version: $(yarn --version)"
