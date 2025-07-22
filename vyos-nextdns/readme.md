# VyOS NextDNS Integration

This package integrates the NextDNS client with the VyOS configuration system.

While Vyos can directly point to NextDNS servers' IP addresses as an upstream resolver, NextDNS CLI is used for more advanced security (DoH and DoT), configurations and management.

This package has several components:

- installation of the latest NextDNS CLI from their GitHub repository
- creation of configuration nodes under 'service' on VyOS
- (light) validation of configuration parameters and translation to nextdns.conf
- service wrapper for starting and stopping the NextDNS service as a systemd service  on VyOS
- clean-up of the NextDNS service and associated files from Vyos configuration when the package is removed

## Installation

1. Download `nextdns_<version>_vyos.deb` to VyOS
2. Install with `sudo dpkg -i nextdns_<version>_vyos.deb`  
        Check: `nextdns version` and `nextdns status` (should be stopped if there is no profile set)  
        Check: `sudo systemctl status nextdns`  
        Check: `sudo journalctl -u nextdns -n 50`  

## Configuration

1. enter configuration mode with `configure`
2. Add desired configuration nodes with `set service nextdns`
(`profile` node is required - get it at [NextDNS portal](https://my.nextdns.io))

- `bogus-priv`            Block private IP reverse lookups, default `true`
- `cache-max-age`         Maximum cache entry age
- `cache-size`            Set DNS cache size, default 0 (disabled)
- `debug`                 Enable debug logging
- `discovery-dns`         DNS server for local network discovery
- `forwarder`             DNS forwarder configuration
- `listen`                Listen address for UDP DNS proxy server, default 53
- `log-queries`           Log DNS queries
- `max-inflight-requests` Maximum number of inflight requests.
- `max-ttl`               Maximum TTL value for clients
- `mdns`                  mDNS handling mode
- `profile`               NextDNS profile ID
- `report-client-info`    Embed client information with queries
- `timeout`               Set DNS query timeout
- `use-hosts`             Use system hosts file for DNS resolution

Once you run `commit`, nextdns.conf will be generated and NextDNS service will resstart.

Checks:

- `nextdns status` (should be running)
- `nextdns config` (show the current configuration)
- `nextdns log` (show the logs of the NextDNS service)
- `nextdns discovered` (show the discovered clients)
- `nextdns cache-stats` (show the cache statistics)
- `nextdns cache-keys` (dump the list of cached entries)
- `nextdns arp` (show the ARP table)
- `nextdns ndp` (show the NDP table)

## Uninstallation

To remove the NextDNS integration package, run:

`sudo dpkg -r vyos-nextdns`

## Usage

Vyos can use NextDNS as direct/primary DNS resolver for vyos:

- `system name-server 127.0.0.1` - for IPv4
- `system name-server ::` - for IPv6

Or can keep using own PowerDNS resolver to respond on defauly port :53 and use NextDNS on a different port as an upstream DoH resolver and ad blocker::

- `set service nextdns listen 9053`
- `set service dns forwarding name-server 127.0.0.1:9053`
- `set service dns forwarding name-server ::9053`

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
