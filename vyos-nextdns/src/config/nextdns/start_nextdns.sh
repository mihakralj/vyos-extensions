#!/bin/bash
set -euo pipefail

# --- Configuration ---
readonly CONFIG_DIR="/config/nextdns"
readonly BINARY_PATH_PERSISTENT="/usr/sbin/nextdns"
readonly SYSTEMD_SERVICE_PATH="/etc/systemd/system/nextdns.service"
readonly GITHUB_API="https://api.github.com/repos/nextdns/nextdns/releases/latest"
readonly LOG_FILE="/var/log/vyos-nextdns_install.log"

# --- Functions ---
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | [START_SCRIPT] | $*" | tee -a "$LOG_FILE"
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

install_nextdns_binary() {
    if [[ ! -f "$BINARY_PATH_PERSISTENT" ]]; then
        log "Downloading NextDNS binary..."
        local api_ip="140.82.121.6"
        local github_ip="140.82.121.4"
        local assets_ip="185.199.108.154"
        local curl_resolve_opts="--resolve api.github.com:443:${api_ip} --resolve github.com:443:${github_ip} --resolve release-assets.githubusercontent.com:443:${assets_ip}"
        log "Fetching latest release info..."
        local latest_release
        latest_release=$(curl --silent --connect-timeout 15 ${curl_resolve_opts} "$GITHUB_API")
        if [[ -z "$latest_release" || "$latest_release" =~ "API rate limit exceeded" ]]; then
            error_exit "Failed to fetch latest release info from GitHub. Check network or try again later."
        fi
        local version
        version=$(echo "$latest_release" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/') || error_exit "Could not parse latest version from GitHub API response."
        log "Latest NextDNS version: $version"
        local arch
        arch=$(uname -m)
        local nextdns_arch
        case "$arch" in
            x86_64) nextdns_arch="amd64" ;;
            aarch64) nextdns_arch="arm64" ;;
            *) error_exit "Unsupported architecture: $arch" ;;
        esac
        log "Detected architecture: $arch (NextDNS arch: $nextdns_arch)"
        local url="https://github.com/nextdns/nextdns/releases/download/v${version}/nextdns_${version}_linux_${nextdns_arch}.tar.gz"
        local temp_dir
        temp_dir=$(mktemp -d)
        log "Downloading from $url..."
        if curl --silent --location --connect-timeout 60 ${curl_resolve_opts} "$url" | tar -xzf - -C "$temp_dir"; then
            log "Installing binary to $BINARY_PATH_PERSISTENT..."
            local extracted_binary
            # Look for executable files named 'nextdns' (more robust)
            extracted_binary=$(find "$temp_dir" -type f -executable -name "nextdns" | head -n 1)
            if [[ -z "$extracted_binary" ]]; then
                # Fallback: look for any file named 'nextdns'
                extracted_binary=$(find "$temp_dir" -type f -name "nextdns" | head -n 1)
            fi
            if [[ -z "$extracted_binary" ]]; then
                log "Archive contents:"
                find "$temp_dir" -type f -exec ls -la {} \;
                rm -rf "$temp_dir"
                error_exit "Could not find 'nextdns' binary in the extracted archive."
            fi
            log "Found binary: $extracted_binary"
            mv "$extracted_binary" "$BINARY_PATH_PERSISTENT"
        else
            rm -rf "$temp_dir"
            error_exit "Failed to download or extract NextDNS binary."
        fi
        rm -rf "$temp_dir"
        chmod 755 "$BINARY_PATH_PERSISTENT"
        log "NextDNS binary installed successfully."
    else
        log "NextDNS binary already exists at $BINARY_PATH_PERSISTENT. Skipping download."
    fi
}

# --- Main Execution ---
main() {
    check_root
    log "--- Starting NextDNS VyOS Integration Setup ---"
    
    install_nextdns_binary
    
    log "Generating VyOS CLI nodes..."
    "$CONFIG_DIR/generate_nodes.sh" || error_exit "Failed to generate VyOS nodes."
    
    log "Deploying and enabling systemd service..."
    ln -sf "$CONFIG_DIR/nextdns.service" "$SYSTEMD_SERVICE_PATH"
    systemctl daemon-reload
    systemctl enable nextdns.service || true
    
    log "Generating config from VyOS settings..."
    "$CONFIG_DIR/service_nextdns.py"
    
    log "--- NextDNS VyOS Integration Setup Complete ---"
}

main "$@"
