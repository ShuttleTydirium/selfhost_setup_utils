#!/bin/ash
set -eux  # Enable debugging and exit on error

# Set environment variables
export PATH=/usr/local/go/bin:$PATH
export GOLANG_VERSION=1.23.2

# Install necessary dependencies
apk add --no-cache --virtual .fetch-deps \
    ca-certificates \
    gnupg \
    tar \
    wget

# Determine the system architecture
arch="$(apk --print-arch)"
case "$arch" in
    'x86_64') 
        url='https://dl.google.com/go/go1.23.2.linux-amd64.tar.gz'
        sha256='542d3c1705f1c6a1c5a80d5dc62e2e45171af291e755d591c5e6531ef63b454e' ;;
    'armhf'|'armv7') 
        url='https://dl.google.com/go/go1.23.2.linux-armv6l.tar.gz'
        sha256='e3286bdde186077e65e961cbe18874d42a461e5b9c472c26572b8d4a98d15c40' ;;
    'aarch64') 
        url='https://dl.google.com/go/go1.23.2.linux-arm64.tar.gz'
        sha256='f626cdd92fc21a88b31c1251f419c17782933a42903db87a174ce74eeecc66a9' ;;
    'x86') 
        url='https://dl.google.com/go/go1.23.2.linux-386.tar.gz'
        sha256='cb1ed4410f68d8be1156cee0a74fcfbdcd9bca377c83db3a9e1b07eebc6d71ef' ;;
    'ppc64le') 
        url='https://dl.google.com/go/go1.23.2.linux-ppc64le.tar.gz'
        sha256='c164ce7d894b10fd861d7d7b96f1dbea3f993663d9f0c30bc4f8ae3915db8b0c' ;;
    'riscv64') 
        url='https://dl.google.com/go/go1.23.2.linux-riscv64.tar.gz'
        sha256='ea8ab49c5c04c9f94a3f4894d1b030fbce8d10413905fa399f6c39c0a44d5556' ;;
    's390x') 
        url='https://dl.google.com/go/go1.23.2.linux-s390x.tar.gz'
        sha256='de1f94d7dd3548ba3036de1ea97eb8243881c22a88fcc04cc08c704ded769e02' ;;
    *) 
        echo "Unsupported architecture '$arch'"; exit 1 ;;
esac

# Download and verify the Go binary
wget -O go.tgz "$url"
echo "$sha256 *go.tgz" | sha256sum -c -

# Configure GPG and verify the signature
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 'EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796'
gpg --batch --keyserver keyserver.ubuntu.com --recv-keys '2F528D36D67B69EDF998D85778BD65473CB3BD13'
wget -O go.tgz.asc "$url.asc"
gpg --batch --verify go.tgz.asc go.tgz
gpgconf --kill all
rm -rf "$GNUPGHOME" go.tgz.asc

# Extract the Go archive and clean up
tar -C /usr/local -xzf go.tgz
rm go.tgz

# Optional reproducibility step
SOURCE_DATE_EPOCH="$(stat -c '%Y' /usr/local/go)"
touchy="$(date -d "@$SOURCE_DATE_EPOCH" '+%Y%m%d%H%M.%S')"
touch -t "$touchy" /usr/local/go

# Handle armv7-specific configuration
if [ "$arch" = 'armv7' ]; then
    { echo; echo 'GOARM=7'; } >> /usr/local/go/go.env
    touch -t "$touchy" /usr/local/go /usr/local/go/go.env
fi

# Prepare directory tree for copying (as Docker would do with `COPY --link`)
mkdir -p /target/usr/local
mv -T /usr/local/go /target/usr/local/go
ln -svfT /target/usr/local/go /usr/local/go
touch -t "$touchy" /target/usr/local /target

# Remove temporary dependencies
apk del --no-network .fetch-deps

# Install ca-certificates for the final environment
apk add --no-cache ca-certificates

# Set up Go environment paths
export GOPATH=/go
export PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

# Create necessary directories with appropriate permissions
mkdir -p "$GOPATH/src" "$GOPATH/bin"
chmod -R 1777 "$GOPATH"

# Verify installation
go version

