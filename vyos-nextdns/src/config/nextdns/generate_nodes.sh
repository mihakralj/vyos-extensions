#!/bin/bash
set -e

TARGET_DIR="/opt/vyatta/share/vyatta-cfg/templates/service/nextdns"
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

# --- Main service node ---
cat > "${TARGET_DIR}/node.def" <<'EOF'
help: NextDNS client settings
priority: 500
end: /usr/bin/python3 /config/nextdns/service_nextdns.py
EOF

# --- All other nodes... (content is the same as before) ---
mkdir -p "${TARGET_DIR}/profile"
cat > "${TARGET_DIR}/profile/node.def" <<'EOF'
multi:
type: txt
help: NextDNS profile ID
val_help: txt; NextDNS profile ID (6 alphanumeric characters)
val_help: txt; Subnet mapping format: 192.168.1.0/24=abcdef
EOF
mkdir -p "${TARGET_DIR}/listen"
cat > "${TARGET_DIR}/listen/node.def" <<'EOF'
type: txt
help: Listen address for UDP DNS proxy server
default: ":53"
val_help: :53; Listen on all interfaces, port 53
val_help: 127.0.0.1:53; Listen on localhost, port 53
syntax:expression: exec "[[ '$VAR(@)' =~ .*:.* ]]"; "Listen address must contain a colon (e.g., :53)"
EOF
mkdir -p "${TARGET_DIR}/cache-size"
cat > "${TARGET_DIR}/cache-size/node.def" <<'EOF'
type: txt
help: Set DNS cache size
default: "10MB"
val_help: txt; Cache size (e.g., 10MB, 0 to disable)
EOF
mkdir -p "${TARGET_DIR}/cache-max-age"
cat > "${TARGET_DIR}/cache-max-age/node.def" <<'EOF'
type: txt
help: Maximum cache entry age
val_help: txt; Duration (e.g., 1h, 30m, 300s)
EOF
mkdir -p "${TARGET_DIR}/timeout"
cat > "${TARGET_DIR}/timeout/node.def" <<'EOF'
type: txt
help: Set DNS query timeout
default: "5s"
val_help: txt; Timeout duration (e.g., 5s, 10s)
EOF
mkdir -p "${TARGET_DIR}/max-ttl"
cat > "${TARGET_DIR}/max-ttl/node.def" <<'EOF'
type: txt
help: Maximum TTL value for clients
val_help: txt; Duration (e.g., 1h, 30m, 300s)
EOF
mkdir -p "${TARGET_DIR}/max-inflight-requests"
cat > "${TARGET_DIR}/max-inflight-requests/node.def" <<'EOF'
type: u32
help: Maximum number of inflight requests.
default: 256
val_help: u32; Number of concurrent requests (1-1024)
syntax:expression: exec "[ '$VAR(@)' -ge 1 ] && [ '$VAR(@)' -le 1024 ]"; "Must be between 1 and 1024"
EOF
mkdir -p "${TARGET_DIR}/log-queries"
cat > "${TARGET_DIR}/log-queries/node.def" <<'EOF'
help: Log DNS queries
EOF
mkdir -p "${TARGET_DIR}/discovery-dns"
cat > "${TARGET_DIR}/discovery-dns/node.def" <<'EOF'
type: ipv4
help: DNS server for local network discovery
val_help: ipv4; IPv4 address of local DNS server
EOF
mkdir -p "${TARGET_DIR}/mdns"
cat > "${TARGET_DIR}/mdns/node.def" <<'EOF'
type: txt
help: discover client information and serve mDNS-learned names.
default: "all"
val_help: all; Forward all mDNS queries
val_help: disabled; Disable mDNS forwarding
syntax:expression: exec "[ '$VAR(@)' = 'all' ] || [ '$VAR(@)' = 'disabled' ]"; "Must be 'all' or 'disabled'"
EOF
mkdir -p "${TARGET_DIR}/bogus-priv"
cat > "${TARGET_DIR}/bogus-priv/node.def" <<'EOF'
help: Block private IP reverse lookups
EOF
mkdir -p "${TARGET_DIR}/report-client-info"
cat > "${TARGET_DIR}/report-client-info/node.def" <<'EOF'
help: Embed client information with queries
EOF
mkdir -p "${TARGET_DIR}/use-hosts"
cat > "${TARGET_DIR}/use-hosts/node.def" <<'EOF'
help: Use system hosts file for DNS resolution
EOF
mkdir -p "${TARGET_DIR}/forwarder"
cat > "${TARGET_DIR}/forwarder/node.def" <<'EOF'
multi:
type: txt
help: DNS forwarder configuration
val_help: txt; Domain forwarder in format: domain=server:port
EOF

chown -R root:vyattacfg "$TARGET_DIR"
find "$TARGET_DIR" -type d -exec chmod 755 {} \;
find "$TARGET_DIR" -type f -exec chmod 644 {} \;
systemctl restart vyos-configd
