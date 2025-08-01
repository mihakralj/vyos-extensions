# VyOS Tailscale Network Integration Guide

## Overview

This guide explains how to integrate Tailscale into your VyOS router's networking configuration. By default, VyOS treats the `tailscale0` interface and its `100.64.0.0/10` address space as an external network. To allow Tailscale clients to access your local LAN or use the VyOS router as an **exit node** or **subnet router**, you must update your firewall and NAT rules.

The core principle is to treat the Tailscale network as another trusted internal network.

## Key Concepts

1. **Tailscale Interface**: Tailscale creates a virtual network interface named `tailscale0`.
2. **Tailscale Subnet**: Tailscale clients are assigned IP addresses from the `100.64.0.0/10` CGNAT range.
3. **Integration Goal**: You need to tell your VyOS firewall and NAT rules to treat `tailscale0` and `100.64.0.0/10` as part of your internal network.

## Step 1: Identify Your Existing Configuration

First, identify your current LAN and WAN settings.

- **WAN Interface**: The interface connected to the internet (e.g., `eth0`).
- **LAN Interface(s)**: The interface(s) for your local network (e.g., `eth1`, `eth2`).
- **LAN Subnet(s)**: Your local IP range (e.g., `192.168.1.0/24`).

## Step 2: Create Firewall Groups

The best practice is to use groups to manage your configuration. This makes it easier to add new interfaces or networks in the future.

### 1. Create an `INTERNAL_INTERFACES` Group

This group will contain all your trusted network interfaces.

```bash
configure
# Add your existing LAN interface(s)
set firewall group interface-group INTERNAL_INTERFACES interface 'eth1'
# Add the Tailscale interface
set firewall group interface-group INTERNAL_INTERFACES interface 'tailscale0'
commit
```

### 2. Create an `INTERNAL_NETWORKS` Group

This group will contain all your trusted IP subnets.

```bash
configure
# Add your existing LAN subnet(s)
set firewall group network-group INTERNAL_NETWORKS network '192.168.1.0/24'
# Add the Tailscale CGNAT subnet
set firewall group network-group INTERNAL_NETWORKS network '100.64.0.0/10'
commit
```

## Step 3: Update Firewall and NAT Rules

Now, update your existing rules to use these new groups.

### 1. Allow Traffic Between Internal Networks (for Subnet Routing)

To allow devices on your Tailscale network to access your physical LAN (and vice-versa), you need a firewall rule that permits traffic *between* all networks in your `INTERNAL_NETWORKS` group. This rule should be placed before your general LAN-to-WAN rule to ensure it is evaluated first.

```bash
# Example: Create a new rule (e.g., rule 5) in your main forward chain
# This allows members of INTERNAL_NETWORKS to talk to each other.
set firewall name INTERNAL-TO-EXTERNAL rule 5 action 'accept'
set firewall name INTERNAL-TO-EXTERNAL rule 5 description 'Allow traffic between internal networks'
set firewall name INTERNAL-TO-EXTERNAL rule 5 source group network-group 'INTERNAL_NETWORKS'
set firewall name INTERNAL-TO-EXTERNAL rule 5 destination group network-group 'INTERNAL_NETWORKS'
commit
```

### 2. Update Internal-to-External Forwarding Rule (for Exit Node)

Update your existing forwarding rule to allow all internal interfaces to access the internet. This is necessary for the exit node functionality.

```bash
# Example: Update rule 10
# First, remove the old specific interface rule
delete firewall name INTERNAL-TO-EXTERNAL rule 10 source interface
# Then, add the new group-based rule
set firewall name INTERNAL-TO-EXTERNAL rule 10 source group interface-group 'INTERNAL_INTERFACES'
commit
```

### Update NAT Source Rules

Update your source NAT (masquerade) rule to apply to traffic from the `INTERNAL_NETWORKS` group.

```bash
# Example: Update rule 100
# First, remove the old specific network rule
delete nat source rule 100 source address
# Then, add the new group-based rule
set nat source rule 100 source group network-group 'INTERNAL_NETWORKS'
commit
save
```

## Step 4: Enable Tailscale Features

With the VyOS networking in place, you can now enable Tailscale's routing features.

### For an Exit Node

Advertise the VyOS router as an exit node.

```bash
configure
set service tailscale exit-node
commit
```

### For a Subnet Router

Advertise your local LAN subnet to your tailnet.

```bash
configure
set service tailscale advertise-routes '192.168.1.0/24'
commit
```

Remember to approve the advertised routes in the [Tailscale Admin Console](https://login.tailscale.com/admin/machines).

## Summary

By grouping your trusted interfaces and networks, you can easily and securely integrate Tailscale into your VyOS router. This approach is scalable and makes it simple to manage your firewall and NAT rules.

**The universal pattern is:**
1.  Group your LAN and `tailscale0` interfaces into an `INTERNAL_INTERFACES` group.
2.  Group your LAN and `100.64.0.0/10` subnets into an `INTERNAL_NETWORKS` group.
3.  Update your firewall and NAT rules to use these groups instead of specific interfaces or subnets.
