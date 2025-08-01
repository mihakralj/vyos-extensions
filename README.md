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

### 🔒 Tailscale (`vyos-tailscale`)

A complete integration package that brings Tailscale VPN client functionality to VyOS with full configuration system support.

**Features:**

- Installation of the latest Tailscale binaries
- Native VyOS configuration nodes under `service tailscale`
- Full support for most `tailscale up` command-line flags
- Systemd service wrapper for VyOS
- Clean uninstallation with configuration cleanup

**Key Benefits:**

- Secure, zero-config VPN that "just works"
- Simple and powerful access control lists (ACLs)
- MagicDNS for easy service discovery
- Exit node support for routing traffic
- Integration with VyOS commit/rollback system

**How to install:**

`wget https://github.com/mihakralj/vyos-extensions/releases/download/vyos-tailscale/tailscale_1.76.1_vyos.deb`
`sudo dpkg -i tailscale_1.76.1_vyos.deb`

**How to remove:**

`sudo dpkg -r vyos-tailscale`

## Rant

VyOS is not an open system for community developers - its configuration schema is semi-compiled during build time and does not allow to add arbitrary configuration nodes during runtime. If donfig node is not in cache, vyos config will throw a fit. And cache is rather large, compact and not tinker-friendly - check it for yourself on runnint vyos:

`/usr/lib/live/mount/rootfs/2025.07.21-0022-rolling.squashfs/usr/lib/python3/dist-packages/vyos/xml_ref/cache.py`

Therefore community packages cannot use the standard VyOS configuration system as its nodes are not pre-compiled in the `cache.py` - and all VyOS validations of node system will fail on check. But there is a workaround...

We can completely ignore built-in configuration validation system that VyOS provides. Instead, we can generate own raw `nodes.def` structure directly, as VyOS is not shipping with `.xml` schemas or compilers (see direct generation of nodes in `generate_nodes.sh` of this package). Nodes structure and validations are all tested thoroughly, but they are *very fragile* as they do not (cannot) rely on VyOS schema or validation system. You don't let me use yours? We'll build our own! 😎

How do we get configuration information out from VyOS when we want to generate `nextdns.conf` or any other service configuration? Default python helpers that VyOS uses do not work - because, yeah, WE ARE NOT IN THE PRE_BAKED SCHEMA.

But we use CLI command `cli-shell-api` instead and parse its output to generate required configuration. This is not a clean solution, but it works. For nextdns I opted to avoid Jinja2 templates as well, as nextdns.conf is very simple to construct. Here is an actual command that pulls configuration from VyOS:

```bash
eval "$(/usr/bin/cli-shell-api getEditResetEnv)" && /usr/bin/cli-shell-api showCfg service nextdns'
```

## License

This project is licensed under the GNU General Public License v2.0, just like VyOS is - see the [LICENSE](LICENSE) file for details.

## Disclaimer

These packages are not officially supported by the VyOS project. Use at your own risk and always test in a non-production environment first.

---

*Making VyOS more extensible, one package at a time.* 🚀
