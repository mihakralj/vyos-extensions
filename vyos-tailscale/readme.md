# VyOS Tailscale Integration

This package integrates the Tailscale VPN client with the VyOS configuration system, allowing for native management of Tailscale settings.

This package has several components:

- Installation of the latest Tailscale binaries from their official repository.
- Creation of configuration nodes under `service tailscale` on VyOS.
- Validation of configuration parameters and translation to `tailscale up` commands.
- A systemd service wrapper for starting and stopping the Tailscale service on VyOS.
- Clean-up of the Tailscale service and associated files from VyOS when the package is removed.

## Installation

1. Download `tailscale_<version>_vyos.deb` to your VyOS system.
2. Install the package with `sudo dpkg -i tailscale_<version>_vyos.deb`.
3. Check the installation:
    - `sudo tailscale version`
    - `sudo systemctl status tailscaled` (should be running if an auth key is configured)
    - `sudo journalctl -u tailscaled -n 50`

## Configuration

1. Enter configuration mode with `configure`.
2. Add your desired configuration nodes using `set service tailscale`.
3. The `auth-key` node is required for the initial setup. You can generate one from the [Tailscale admin console](https://login.tailscale.com/admin/settings/keys).

### Configuration Options

- `auth-key` **(Required)**: Your Tailscale authentication key.
- `exit-node`: Use this device as an exit node.
- `exit-node-allow-lan-access`: Allow LAN access when using an exit node.
- `advertise-routes`: Announce local subnets to other Tailscale nodes.
- `accept-routes`: Accept routes from other nodes in your tailnet.
- `hostname`: Set a custom hostname for this device on the Tailscale network.
- `netfilter-mode`: Control how Tailscale interacts with `nftables` or `iptables`.
- `snat-subnet-routes`: Automatically enable SNAT for advertised subnets.
- `shields-up`: Block all incoming connections from other nodes.
- `accept-dns`: Accept DNS settings from the Tailscale network.

Once you run `commit`, the configuration will be applied, and the Tailscale service will restart.

### Post-Installation Checks

- `sudo tailscale status`: Verify connection to the Tailscale network.
- `sudo tailscale netcheck`: Check for connectivity issues.
- `show service tailscale`: Review the current VyOS configuration.

## Uninstallation

To remove the Tailscale integration package, run:

`sudo dpkg -r vyos-tailscale`

To completely remove all configuration files, use the purge command:

`sudo dpkg --purge vyos-tailscale`

## Usage

Once installed and configured, your VyOS router will be a node on your Tailscale network. You can use it as a gateway to your local network by advertising routes and enabling `snat-subnet-routes`. You can also use it as an exit node to route traffic from other devices through your VyOS router's internet connection.

For detailed instructions on how to configure your VyOS firewall and NAT rules to work with Tailscale, please see the [Network Integration Guide](network_setup.md).
