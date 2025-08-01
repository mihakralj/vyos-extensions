#!/bin/bash

# Tailscale Cleanup Script
# Stops tailscaled service and removes Tailscale files from /config/tailscale

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

clean_tailscale() {
    log "Starting Tailscale cleanup process"

    log "Logging out of Tailscale..."
    sudo /config/tailscale/tailscale logout || log "Warning: Failed to log out. Already logged out?"

    # Stop tailscaled service
    log "Stopping tailscaled service..."
    if systemctl is-active --quiet tailscaled.service; then
        systemctl stop tailscaled.service || error_exit "Failed to stop tailscaled service"
        log "Successfully stopped tailscaled service"
    else
        log "tailscaled service is not running"
    fi

    # Disable the service
    log "Disabling tailscaled service..."
    if systemctl is-enabled --quiet tailscaled.service; then
        systemctl disable tailscaled.service || error_exit "Failed to disable tailscaled service"
        log "Successfully disabled tailscaled service"
    else
        log "tailscaled service is not enabled"
    fi

    # Remove files from /config/tailscale/
    log "Removing Tailscale files from /config/tailscale/"

    local files=(
        "/config/tailscale/tailscaled.env"
        "/config/tailscale/tailscaled.service"
        "/config/tailscale/tailscale"
        "/config/tailscale/tailscaled"
    )

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file" || error_exit "Failed to remove $file"
            log "Removed: $file"
        else
            log "File not found (skipping): $file"
        fi
    done

    # Remove symlinks
    log "Removing system symlinks..."
    local symlinks=(
        "/etc/default/tailscaled"
        "/lib/systemd/system/tailscaled.service"
        "/usr/bin/tailscale"
        "/usr/sbin/tailscaled"
    )

    for symlink in "${symlinks[@]}"; do
        if [[ -L "$symlink" ]]; then
            rm -f "$symlink" || error_exit "Failed to remove symlink $symlink"
            log "Removed symlink: $symlink"
        else
            log "Symlink not found (skipping): $symlink"
        fi
    done

    log "Removing IP forwarding configuration..."
    sudo rm -f /etc/sysctl.d/99-tailscale.conf
    log "IP forwarding configuration removed."

    # Revert ethtool settings
    log "Reverting ethtool optimizations..."
    NETDEV=$(ip -o route get 8.8.8.8 | cut -f 5 -d " ")
    if [[ -n "$NETDEV" ]]; then
        sudo ethtool -K $NETDEV rx-udp-gro-forwarding off rx-gro-list on || log "Warning: Failed to revert ethtool settings. This may not be supported on your hardware."
        log "Successfully reverted ethtool settings on $NETDEV"
    else
        log "Warning: Could not determine the primary network device. Skipping ethtool optimizations."
    fi

    # Reload systemd daemon
    log "Reloading systemd daemon..."
    systemctl daemon-reload || error_exit "Failed to reload systemd daemon"

    log "Tailscale cleanup completed successfully"
}

# Main execution
main() {
    check_root
    clean_tailscale
}

# Run main function
main "$@"
