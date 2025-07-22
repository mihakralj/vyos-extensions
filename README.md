# VyOS Extensions

A collection of packages, plugins, and extensions for VyOS - stuff added for fun, functionality and experimentation..

## Overview

VyOS is a powerful routing/firewalling system, but its configuration schema is hard-baked during build time and doesn't allow for arbitrary configuration nodes being added during runtime. This repository provides crafted packages that work around these limitations and extend VyOS functionality with new services and features.

## Current Packages

### 🚀 NextDNS (`vyos-nextdns`)

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

**How to install:**

`wget https://github.com/mihakralj/vyos-extensions/releases/download/vyos-nextdns/nextdns_1.46.0_vyos.deb`
`sudo dpkg -i nextdns_1.46.0_vyos.deb`

**How to remove:**

`sudo dpkg -r vyos-nextdns`


## License

This project is licensed under the GNU General Public License v2.0, just like VyOS is - see the [LICENSE](LICENSE) file for details.

## Disclaimer

These packages are not officially supported by the VyOS project. Use at your own risk and always test in a non-production environment first.

---

*Making VyOS more extensible, one package at a time.* 🚀
