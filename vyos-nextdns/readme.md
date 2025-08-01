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
