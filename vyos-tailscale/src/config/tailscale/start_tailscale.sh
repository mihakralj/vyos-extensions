#!/bin/bash

# Tailscale Download and Extract Script
# Downloads latest tailscale .deb package to /tmp, extracts to /tmp/tailscale, and lists contents

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error_exit() {
    echo "[ERROR] $*" >&2
    exit 1
}

# Check if running as root
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error_exit "This script must be run as root."
    fi
}

# Check required commands
check_prerequisites() {
    command -v curl >/dev/null 2>&1 || error_exit "curl is required but not installed"
    command -v wget >/dev/null 2>&1 || error_exit "wget is required but not installed"
    command -v dpkg-deb >/dev/null 2>&1 || error_exit "dpkg-deb is required but not installed"
}

download_and_extract_tailscale() {
    local BUILD="${1:-stable}"
    local DIST="${2:-bookworm}"
    local BASE="https://pkgs.tailscale.com/${BUILD}/debian"
    local INDEX_URL="${BASE}/dists/${DIST}/main/binary-amd64/Packages.gz"

    # Create temp files
    TMP_INDEX="$(mktemp)"
    DEB_FILE="$(mktemp --suffix=.deb)"
    trap 'rm -f "$TMP_INDEX" "$DEB_FILE"' EXIT

    log "Fetching package index: $INDEX_URL"
    curl -fsSL "$INDEX_URL" -o "$TMP_INDEX" || error_exit "Failed to fetch package index"

    # Detect compression and set decompression command
    local DECOMP
    if head -c2 "$TMP_INDEX" | grep -q $'\x1f\x8b'; then
        DECOMP="gunzip -c"
    else
        DECOMP="cat"
    fi

    # Find the latest version
    local VERSION
    VERSION=$(
        $DECOMP "$TMP_INDEX" \
            | awk '/^Version:/{print $2}' \
            | sort -Vr \
            | head -n1
    )
    if [[ -z "$VERSION" ]]; then
        error_exit "No Version found in package index"
    fi
    log "Latest version found: $VERSION"

    # Find the filename for this version
    local FILENAME
    FILENAME=$(
        $DECOMP "$TMP_INDEX" \
            | awk -v ver="$VERSION" '
                $1=="Version:" && $2==ver { inside=1 }
                inside && /^Filename:/ { print $2; exit }
                inside && /^$/ { inside=0 }
              '
    )
    if [[ -z "$FILENAME" ]]; then
        error_exit "No Filename found for version $VERSION"
    fi

    local URL="$BASE/$FILENAME"

    log "Downloading .deb package to temporary file"
    log "URL: $URL"
    wget -q --show-progress -O "$DEB_FILE" "$URL" || error_exit "Failed to download package"

    log "Successfully downloaded: $DEB_FILE"

    # Clean up any existing extraction directory
    rm -rf "/tmp/tailscale"

    # Extract the package to /tmp/tailscale
    log "Extracting package contents to /tmp/tailscale"
    mkdir -p "/tmp/tailscale"
    dpkg-deb -x "$DEB_FILE" "/tmp/tailscale" || error_exit "Failed to extract package"

    log "Extraction completed successfully"

    # List the contents of /tmp/tailscale
    log "Contents of /tmp/tailscale:"
    find /tmp/tailscale -type f -exec ls -la {} \; | sed 's/^/  /'

    # Copy files to /config/tailscale/
    log "Copying files to /config/tailscale/"
    mkdir -p "/config/tailscale"

    # Copy default config
    if [[ -f "/tmp/tailscale/etc/default/tailscaled" ]]; then
        cp "/tmp/tailscale/etc/default/tailscaled" "/config/tailscale/tailscaled.env" || error_exit "Failed to copy default config"
        ln -sf "/config/tailscale/tailscaled.env" "/etc/default/tailscaled" || error_exit "Failed to create symlink for default config"
        log "Successfully copied /tmp/tailscale/etc/default/tailscaled to /config/tailscale/tailscaled.env"
        log "Created symlink /etc/default/tailscaled -> /config/tailscale/tailscaled.env"
    else
        log "Warning: /tmp/tailscale/etc/default/tailscaled not found in extracted package"
    fi

    # Copy systemd service file
    if [[ -f "/tmp/tailscale/lib/systemd/system/tailscaled.service" ]]; then
        cp "/tmp/tailscale/lib/systemd/system/tailscaled.service" "/config/tailscale/tailscaled.service" || error_exit "Failed to copy service file"
        ln -sf "/config/tailscale/tailscaled.service" "/lib/systemd/system/tailscaled.service" || error_exit "Failed to create symlink for service file"
        log "Successfully copied /tmp/tailscale/lib/systemd/system/tailscaled.service to /config/tailscale/tailscaled.service"
        log "Created symlink /lib/systemd/system/tailscaled.service -> /config/tailscale/tailscaled.service"
    else
        log "Warning: /tmp/tailscale/lib/systemd/system/tailscaled.service not found in extracted package"
    fi

    # Copy tailscale binary
    if [[ -f "/tmp/tailscale/usr/bin/tailscale" ]]; then
        cp "/tmp/tailscale/usr/bin/tailscale" "/config/tailscale/tailscale" || error_exit "Failed to copy tailscale binary"
        ln -sf "/config/tailscale/tailscale" "/usr/bin/tailscale" || error_exit "Failed to create symlink for tailscale binary"
        chmod +x "/config/tailscale/tailscale"
        log "Successfully copied /tmp/tailscale/usr/bin/tailscale to /config/tailscale/tailscale"
        log "Created symlink /usr/bin/tailscale -> /config/tailscale/tailscale"
    else
        log "Warning: /tmp/tailscale/usr/bin/tailscale not found in extracted package"
    fi

    # Copy tailscaled daemon
    if [[ -f "/tmp/tailscale/usr/sbin/tailscaled" ]]; then
        cp "/tmp/tailscale/usr/sbin/tailscaled" "/config/tailscale/tailscaled" || error_exit "Failed to copy tailscaled daemon"
        ln -sf "/config/tailscale/tailscaled" "/usr/sbin/tailscaled" || error_exit "Failed to create symlink for tailscaled daemon"
        chmod +x "/config/tailscale/tailscaled"
        log "Successfully copied /tmp/tailscale/usr/sbin/tailscaled to /config/tailscale/tailscaled"
        log "Created symlink /usr/sbin/tailscaled -> /config/tailscale/tailscaled"
    else
        log "Warning: /tmp/tailscale/usr/sbin/tailscaled not found in extracted package"
    fi

    # Clean up temp files (handled by trap)
}

# Main execution
main() {
    check_root
    log "Starting Tailscale download and extract script"

    check_prerequisites
    download_and_extract_tailscale "$@"

    # Reload systemd and enable the service
    log "Reloading systemd daemon..."
    systemctl daemon-reload || error_exit "Failed to reload systemd daemon"

    log "Enabling tailscaled service..."
    systemctl enable tailscaled.service || error_exit "Failed to enable tailscaled service"

    log "Starting tailscaled service..."
    systemctl start tailscaled.service || error_exit "Failed to start tailscaled service"

    log "Enabling IP forwarding..."
    echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-tailscale.conf > /dev/null
    echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf > /dev/null
    sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
    log "IP forwarding enabled."

    log "Applying ethtool optimizations..."
    NETDEV=$(ip -o route get 8.8.8.8 | cut -f 5 -d " ")
    if [[ -n "$NETDEV" ]]; then
        sudo ethtool -K $NETDEV rx-udp-gro-forwarding on rx-gro-list off || log "Warning: Failed to apply ethtool settings. This may not be supported on your hardware."
        log "Successfully applied ethtool settings to $NETDEV"
    else
        log "Warning: Could not determine the primary network device. Skipping ethtool optimizations."
    fi

    log "Script completed successfully"
}

# Run main function with all arguments
main "$@"

#!/bin/bash

# Tailscale Download and Extract Script
# Downloads latest tailscale .deb package to /tmp, extracts to /tmp/tailscale, and lists contents

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error_exit() {
    echo "[ERROR] $*" >&2
    exit 1
}

# Check if running as root
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error_exit "This script must be run as root."
    fi
}

# Check required commands
check_prerequisites() {
    command -v curl >/dev/null 2>&1 || error_exit "curl is required but not installed"
    command -v wget >/dev/null 2>&1 || error_exit "wget is required but not installed"
    command -v dpkg-deb >/dev/null 2>&1 || error_exit "dpkg-deb is required but not installed"
}

download_and_extract_tailscale() {
    local BUILD="${1:-stable}"
    local DIST="${2:-bookworm}"
    local BASE="https://pkgs.tailscale.com/${BUILD}/debian"
    local INDEX_URL="${BASE}/dists/${DIST}/main/binary-amd64/Packages.gz"

    # Create temp files
    TMP_INDEX="$(mktemp)"
    DEB_FILE="$(mktemp --suffix=.deb)"
    trap 'rm -f "$TMP_INDEX" "$DEB_FILE"' EXIT

    log "Fetching package index: $INDEX_URL"
    curl -fsSL "$INDEX_URL" -o "$TMP_INDEX" || error_exit "Failed to fetch package index"

    # Detect compression and set decompression command
    local DECOMP
    if head -c2 "$TMP_INDEX" | grep -q $'\x1f\x8b'; then
        DECOMP="gunzip -c"
    else
        DECOMP="cat"
    fi

    # Find the latest version
    local VERSION
    VERSION=$(
        $DECOMP "$TMP_INDEX" \
            | awk '/^Version:/{print $2}' \
            | sort -Vr \
            | head -n1
    )
    if [[ -z "$VERSION" ]]; then
        error_exit "No Version found in package index"
    fi
    log "Latest version found: $VERSION"

    # Find the filename for this version
    local FILENAME
    FILENAME=$(
        $DECOMP "$TMP_INDEX" \
            | awk -v ver="$VERSION" '
                $1=="Version:" && $2==ver { inside=1 }
                inside && /^Filename:/ { print $2; exit }
                inside && /^$/ { inside=0 }
              '
    )
    if [[ -z "$FILENAME" ]]; then
        error_exit "No Filename found for version $VERSION"
    fi

    local URL="$BASE/$FILENAME"

    log "Downloading .deb package to temporary file"
    log "URL: $URL"
    wget -q --show-progress -O "$DEB_FILE" "$URL" || error_exit "Failed to download package"

    log "Successfully downloaded: $DEB_FILE"

    # Clean up any existing extraction directory
    rm -rf "/tmp/tailscale"

    # Extract the package to /tmp/tailscale
    log "Extracting package contents to /tmp/tailscale"
    mkdir -p "/tmp/tailscale"
    dpkg-deb -x "$DEB_FILE" "/tmp/tailscale" || error_exit "Failed to extract package"

    log "Extraction completed successfully"

    # List the contents of /tmp/tailscale
    log "Contents of /tmp/tailscale:"
    find /tmp/tailscale -type f -exec ls -la {} \; | sed 's/^/  /'

    # Copy files to /config/tailscale/
    log "Copying files to /config/tailscale/"
    mkdir -p "/config/tailscale"

    # Copy default config
    if [[ -f "/tmp/tailscale/etc/default/tailscaled" ]]; then
        cp "/tmp/tailscale/etc/default/tailscaled" "/config/tailscale/tailscaled.env" || error_exit "Failed to copy default config"
        ln -sf "/config/tailscale/tailscaled.env" "/etc/default/tailscaled" || error_exit "Failed to create symlink for default config"
        log "Successfully copied /tmp/tailscale/etc/default/tailscaled to /config/tailscale/tailscaled.env"
        log "Created symlink /etc/default/tailscaled -> /config/tailscale/tailscaled.env"
    else
        log "Warning: /tmp/tailscale/etc/default/tailscaled not found in extracted package"
    fi

    # Copy systemd service file
    if [[ -f "/tmp/tailscale/lib/systemd/system/tailscaled.service" ]]; then
        cp "/tmp/tailscale/lib/systemd/system/tailscaled.service" "/config/tailscale/tailscaled.service" || error_exit "Failed to copy service file"
        ln -sf "/config/tailscale/tailscaled.service" "/lib/systemd/system/tailscaled.service" || error_exit "Failed to create symlink for service file"
        log "Successfully copied /tmp/tailscale/lib/systemd/system/tailscaled.service to /config/tailscale/tailscaled.service"
        log "Created symlink /lib/systemd/system/tailscaled.service -> /config/tailscale/tailscaled.service"
    else
        log "Warning: /tmp/tailscale/lib/systemd/system/tailscaled.service not found in extracted package"
    fi

    # Copy tailscale binary
    if [[ -f "/tmp/tailscale/usr/bin/tailscale" ]]; then
        cp "/tmp/tailscale/usr/bin/tailscale" "/config/tailscale/tailscale" || error_exit "Failed to copy tailscale binary"
        ln -sf "/config/tailscale/tailscale" "/usr/bin/tailscale" || error_exit "Failed to create symlink for tailscale binary"
        chmod +x "/config/tailscale/tailscale"
        log "Successfully copied /tmp/tailscale/usr/bin/tailscale to /config/tailscale/tailscale"
        log "Created symlink /usr/bin/tailscale -> /config/tailscale/tailscale"
    else
        log "Warning: /tmp/tailscale/usr/bin/tailscale not found in extracted package"
    fi

    # Copy tailscaled daemon
    if [[ -f "/tmp/tailscale/usr/sbin/tailscaled" ]]; then
        cp "/tmp/tailscale/usr/sbin/tailscaled" "/config/tailscale/tailscaled" || error_exit "Failed to copy tailscaled daemon"
        ln -sf "/config/tailscale/tailscaled" "/usr/sbin/tailscaled" || error_exit "Failed to create symlink for tailscaled daemon"
        chmod +x "/config/tailscale/tailscaled"
        log "Successfully copied /tmp/tailscale/usr/sbin/tailscaled to /config/tailscale/tailscaled"
        log "Created symlink /usr/sbin/tailscaled -> /config/tailscale/tailscaled"
    else
        log "Warning: /tmp/tailscale/usr/sbin/tailscaled not found in extracted package"
    fi

    # Clean up temp files (handled by trap)
}

# Main execution
main() {
    check_root
    log "Starting Tailscale download and extract script"

    check_prerequisites
    download_and_extract_tailscale "$@"

    # Generate VyOS configuration nodes
    log "Generating VyOS configuration nodes..."
    if [[ -f "/config/tailscale/generate_nodes.sh" ]]; then
        /config/tailscale/generate_nodes.sh || error_exit "Failed to generate VyOS nodes"
        log "Successfully generated VyOS nodes."
    else
        log "Warning: /config/tailscale/generate_nodes.sh not found. Skipping node generation."
    fi

    # Reload systemd and enable the service
    log "Reloading systemd daemon..."
    systemctl daemon-reload || error_exit "Failed to reload systemd daemon"

    log "Enabling tailscaled service..."
    systemctl enable tailscaled.service || error_exit "Failed to enable tailscaled service"

    log "Starting tailscaled service..."
    systemctl start tailscaled.service || error_exit "Failed to start tailscaled service"

    log "Enabling IP forwarding..."
    echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-tailscale.conf > /dev/null
    echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf > /dev/null
    sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
    log "IP forwarding enabled."

    log "Applying ethtool optimizations..."
    NETDEV=$(ip -o route get 8.8.8.8 | cut -f 5 -d " ")
    if [[ -n "$NETDEV" ]]; then
        sudo ethtool -K $NETDEV rx-udp-gro-forwarding on rx-gro-list off || log "Warning: Failed to apply ethtool settings. This may not be supported on your hardware."
        log "Successfully applied ethtool settings to $NETDEV"
    else
        log "Warning: Could not determine the primary network device. Skipping ethtool optimizations."
    fi

    log "Script completed successfully"
}

# Run main function with all arguments
main "$@"
