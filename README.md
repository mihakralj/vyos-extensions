# VyOS Extensions

A collection of packages, plugins, and extensions for VyOS - stuff added for fun, functionality and experimentation..

## Overview

VyOS is a powerful network operating system, but its configuration schema is semi-compiled during build time and doesn't allow for arbitrary configuration nodes during runtime. This repository provides crafted packages that work around these limitations and extend VyOS functionality with new services and features.

## Current Packages

### 🚀 NextDNS Integration (`vyos-nextdns`)

A complete integration package that brings NextDNS client functionality to VyOS with full configuration system support.

**Features:**
- Installation of the latest NextDNS CLI from GitHub
- Native VyOS configuration nodes under `service nextdns`
- Parameter validation and translation to nextdns.conf
- Systemd service wrapper for VyOS
- Clean uninstallation with configuration cleanup

**Key Benefits:**
- Advanced DNS security with DoH and DoT support
- Ad blocking and malware protection
- Client analytics and logging
- Custom DNS rules and policies
- Integration with VyOS commit/rollback system

**Quick Start:**
```bash
# Download and install
sudo dpkg -i nextdns_<version>_vyos.deb

# Configure in VyOS
configure
set service nextdns profile <your-profile-id>
set service nextdns listen 53
commit
save
```

**Configuration Options:**
- `profile` - NextDNS profile ID (required - get from https://my.nextdns.io)
- `listen` - Listen port for DNS proxy (default: 53)
- `cache-size` - DNS cache size (default: 0/disabled)
- `cache-max-age` - Maximum cache entry age
- `bogus-priv` - Block private IP reverse lookups (default: true)
- `log-queries` - Enable DNS query logging
- `debug` - Enable debug logging
- And many more...

## Installation

### Prerequisites
- VyOS 1.3+ or VyOS 1.4+ rolling release
- Root/admin access to VyOS system

### Build from Source
```bash
# Clone repository
git clone https://github.com/mihakralj/vyos-extensions.git
cd vyos-extensions

# Build NextDNS package (requires WSL on Windows or Linux system)
cd vyos-nextdns
./build_nextdns_deb.sh

# Install on VyOS
scp nextdns_*.deb admin@<vyos-ip>:/config
ssh admin@<vyos-ip>
sudo dpkg -i /config/nextdns_*.deb
```

## Technical Details

### VyOS Configuration System Workaround

VyOS uses a compiled configuration cache that doesn't allow runtime additions of new configuration nodes. This repository uses a clever workaround:

1. **Raw Node Generation**: Direct creation of `nodes.def` structures without relying on VyOS schema compilation
2. **CLI Parsing**: Using `cli-shell-api` to extract configuration data
3. **Service Integration**: Proper systemd integration that respects VyOS service management

### Package Structure
```
vyos-nextdns/
├── build_nextdns_deb.sh     # Build script
├── readme.md                # Package documentation
└── src/
    ├── DEBIAN/              # Package control files
    │   ├── control          # Package metadata
    │   ├── postinst         # Post-installation script
    │   ├── prerm            # Pre-removal script
    │   └── postrm           # Post-removal script
    └── config/nextdns/      # VyOS integration files
        ├── generate_nodes.sh    # Configuration node generator
        ├── nextdns.service      # Systemd service
        ├── service_nextdns.py   # Service management
        └── start_nextdns.sh     # Service startup script
```

## Roadmap

This repository aims to become the go-to collection for VyOS extensions. Planned packages include:

- **Unbound DNS with DoT/DoH** - Advanced DNS resolver with encryption
- **Tailscale Integration** - Zero-config VPN mesh networking  
- **Crowdsec Integration** - Collaborative security and IP reputation
- **AdGuard Home** - Network-wide ad blocking and DNS filtering
- **WireGuard UI** - Web interface for WireGuard VPN management
- **Network UPS Tools** - UPS monitoring and management
- **SNMP Extensions** - Additional SNMP monitoring capabilities

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test thoroughly on VyOS
4. Submit a pull request with detailed description

### Development Guidelines
- Follow existing package structure
- Include comprehensive documentation
- Test installation/removal procedures
- Ensure proper VyOS integration
- Maintain compatibility with VyOS versions

## Support

- **Issues**: Report bugs and feature requests via GitHub Issues
- **Documentation**: Each package includes detailed README
- **Community**: VyOS community forums and Discord

## License

This project is licensed under the GNU General Public License v2.0 - see the [LICENSE](LICENSE) file for details.

## Disclaimer

These packages are community-maintained extensions and are not officially supported by the VyOS project. Use at your own risk and always test in a non-production environment first.

---

*Making VyOS more extensible, one package at a time.* 🚀
