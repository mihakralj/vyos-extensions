#!/bin/bash
set -e
TARGET_DIR="/opt/vyatta/share/vyatta-cfg/templates/service/tailscale"
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

cat > "${TARGET_DIR}/node.def" <<'EOF'
help: Tailscale VPN client settings
priority: 500
end: /usr/bin/python3 /config/tailscale/service_tailscale.py
EOF

mkdir -p "${TARGET_DIR}/auth-key"
cat > "${TARGET_DIR}/auth-key/node.def" <<'EOF'
type: txt
help: Node authorization key
val_help: txt; Authorization key or file path (prefix with "file:" for file path)
EOF

mkdir -p "${TARGET_DIR}/advertise"
cat > "${TARGET_DIR}/advertise/node.def" <<'EOF'
help: Advertising settings
EOF

mkdir -p "${TARGET_DIR}/advertise/exit-node"
cat > "${TARGET_DIR}/advertise/exit-node/node.def" <<'EOF'
help: Offer to be an exit node for internet traffic for the tailnet
EOF

mkdir -p "${TARGET_DIR}/advertise/route"
cat > "${TARGET_DIR}/advertise/route/node.def" <<'EOF'
multi:
type: txt
help: CIDR network to advertise
val_help: txt; CIDR network (e.g., 10.0.0.0/8, 192.168.0.0/24)
syntax:expression: exec "echo '$VAR(@)' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$'"; "Must be a valid CIDR network (e.g., 192.168.1.0/24)"
EOF

mkdir -p "${TARGET_DIR}/advertise/tag"
cat > "${TARGET_DIR}/advertise/tag/node.def" <<'EOF'
multi:
type: txt
help: ACL tag to request (should NOT start with "tag:")
val_help: txt; ACL tag without "tag:" prefix (e.g., eng, montreal, ssh)
syntax:expression: exec "echo '$VAR(@)' | grep -vE '^tag:'"; "Must NOT start with 'tag:'"
EOF

mkdir -p "${TARGET_DIR}/hostname"
cat > "${TARGET_DIR}/hostname/node.def" <<'EOF'
type: txt
help: Hostname to use instead of the one provided by the OS
val_help: txt; Custom hostname for this Tailscale node
EOF

mkdir -p "${TARGET_DIR}/netfilter-mode"
cat > "${TARGET_DIR}/netfilter-mode/node.def" <<'EOF'
type: txt
help: Netfilter mode
default: "on"
val_help: on; Enable netfilter (default)
val_help: nodivert; No divert mode
val_help: off; Disable netfilter
syntax:expression: exec "[ '$VAR(@)' = 'on' ] || [ '$VAR(@)' = 'nodivert' ] || [ '$VAR(@)' = 'off' ]"; "Must be 'on', 'nodivert', or 'off'"
EOF

mkdir -p "${TARGET_DIR}/stop-snat-subnet-routes"
cat > "${TARGET_DIR}/stop-snat-subnet-routes/node.def" <<'EOF'
help: Disable source NAT traffic to local routes advertised with advertise-routes
EOF

mkdir -p "${TARGET_DIR}/ssh"
cat > "${TARGET_DIR}/ssh/node.def" <<'EOF'
help: Run an SSH server, permitting access per tailnet admin's declared policy
EOF

mkdir -p "${TARGET_DIR}/stateful-filtering"
cat > "${TARGET_DIR}/stateful-filtering/node.def" <<'EOF'
help: Apply stateful filtering to forwarded packets (subnet routers, exit nodes, etc.)
EOF

mkdir -p "${TARGET_DIR}/ignore-dns"
cat > "${TARGET_DIR}/ignore-dns/node.def" <<'EOF'
help: Ignore DNS configuration received from the admin panel
EOF

mkdir -p "${TARGET_DIR}/shields-up"
cat > "${TARGET_DIR}/shields-up/node.def" <<'EOF'
help: Don't allow incoming connections
EOF

mkdir -p "${TARGET_DIR}/timeout"
cat > "${TARGET_DIR}/timeout/node.def" <<'EOF'
type: txt
help: Maximum amount of time to wait for tailscaled to enter a Running state
val_help: txt; Duration (e.g., 30s, 1m, 5m) or 0s to block forever
default: "0s"
syntax:expression: exec "echo '$VAR(@)' | grep -E '^[0-9]+[smh]?$'"; "Must be a duration (e.g., 30s, 1m, 5m) or 0s"
EOF

chown -R root:vyattacfg "$TARGET_DIR"
find "$TARGET_DIR" -type d -exec chmod 755 {} \;
find "$TARGET_DIR" -type f -exec chmod 644 {} \;
systemctl restart vyos-configd
