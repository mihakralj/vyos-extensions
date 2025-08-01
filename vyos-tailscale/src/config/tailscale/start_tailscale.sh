#!/bin/bash
set -euo pipefail

# --- Configuration ---
readonly CONFIG_DIR="/config/tailscale"
readonly BINARY_PATH_PERSISTENT="$CONFIG_DIR/tailscaled"
readonly LOG_FILE="/var/log/vyos-tailscale_install.log"

# --- Functions ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] | [START_SCRIPT] | $*" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error_exit "This script must be run as root."
    fi
}

check_prerequisites() {
    command -v curl >/dev/null 2>&1 || error_exit "curl is required but not installed"
    command -v wget >/dev/null 2>&1 || error_exit "wget is required but not installed"
    command -v dpkg-deb >/dev/null 2>&1 || error_exit "dpkg-deb is required but not installed"
}

install_tailscale_binary() {
    if [[ ! -f "$BINARY_PATH_PERSISTENT" ]]; then
        log "Tailscale binary not found. Starting download and installation..."

        if systemctl is-active --quiet tailscaled.service; then
            log "Stopping existing tailscaled service before update..."
            systemctl stop tailscaled.service || log "Warning: Failed to stop tailscaled service."
        fi

        local BUILD="${1:-stable}"
        local DIST="${2:-bookworm}"
        local BASE="https://pkgs.tailscale.com/${BUILD}/debian"
        local INDEX_URL="${BASE}/dists/${DIST}/main/binary-amd64/Packages.gz"

        TMP_INDEX="$(mktemp)"
        DEB_FILE="$(mktemp --suffix=.deb)"
        trap 'rm -f "$TMP_INDEX" "$DEB_FILE"' EXIT

        log "Fetching package index: $INDEX_URL"
        curl -fsSL "$INDEX_URL" -o "$TMP_INDEX" || error_exit "Failed to fetch package index"

        local DECOMP
        if head -c2 "$TMP_INDEX" | grep -q $''; then
            DECOMP="gunzip -c"
        else
            DECOMP="cat"
        fi

        local VERSION
        VERSION=$($DECOMP "$TMP_INDEX" | awk '/^Version:/{print $2}' | sort -Vr | head -n1)
        [[ -n "$VERSION" ]] || error_exit "No Version found in package index"
        log "Latest version found: $VERSION"

        local FILENAME
        FILENAME=$($DECOMP "$TMP_INDEX" | awk -v ver="$VERSION" '$1=="Version:" && $2==ver { inside=1 } inside && /^Filename:/ { print $2; exit } inside && /^$/ { inside=0 }')
        [[ -n "$FILENAME" ]] || error_exit "No Filename found for version $VERSION"

        local URL="$BASE/$FILENAME"
        log "Downloading .deb package from $URL"
        wget -q --show-progress -O "$DEB_FILE" "$URL" || error_exit "Failed to download package"

        rm -rf "/tmp/tailscale"
        mkdir -p "/tmp/tailscale"
        dpkg-deb -x "$DEB_FILE" "/tmp/tailscale" || error_exit "Failed to extract package"
        log "Extraction completed successfully"

        mkdir -p "$CONFIG_DIR"
        cp "/tmp/tailscale/etc/default/tailscaled" "$CONFIG_DIR/tailscaled.env"
        ln -sf "$CONFIG_DIR/tailscaled.env" "/etc/default/tailscaled"

        cp "/tmp/tailscale/lib/systemd/system/tailscaled.service" "$CONFIG_DIR/tailscaled.service"
        ln -sf "$CONFIG_DIR/tailscaled.service" "/lib/systemd/system/tailscaled.service"

        cp "/tmp/tailscale/usr/bin/tailscale" "$CONFIG_DIR/tailscale"
        ln -sf "$CONFIG_DIR/tailscale" "/usr/bin/tailscale"
        chmod +x "$CONFIG_DIR/tailscale"

        cp "/tmp/tailscale/usr/sbin/tailscaled" "$BINARY_PATH_PERSISTENT"
        ln -sf "$BINARY_PATH_PERSISTENT" "/usr/sbin/tailscaled"
        chmod +x "$BINARY_PATH_PERSISTENT"

        log "Tailscale binaries installed successfully."
    else
        log "Tailscale binary already exists at $BINARY_PATH_PERSISTENT. Skipping download."
    fi
}

# --- Main Execution ---
main() {
    check_root
    log "--- Starting Tailscale VyOS Integration Setup ---"

    check_prerequisites
    install_tailscale_binary "$@"

    log "Generating VyOS CLI nodes..."
    "$CONFIG_DIR/generate_nodes.sh" || error_exit "Failed to generate VyOS nodes."

    log "Reloading systemd daemon and enabling service..."
    systemctl daemon-reload
    systemctl enable tailscaled.service || true

    log "Starting tailscaled service before applying configuration..."
    systemctl start tailscaled.service || error_exit "Failed to start tailscaled service"

    log "Applying configuration..."
    "$CONFIG_DIR/service_tailscale.py"

    log "Enabling IP forwarding..."
    echo 'net.ipv4.ip_forward = 1' | tee /etc/sysctl.d/99-tailscale.conf > /dev/null
    echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.d/99-tailscale.conf > /dev/null
    sysctl -p /etc/sysctl.d/99-tailscale.conf

    log "--- Tailscale VyOS Integration Setup Complete ---"
}

main "$@"
