# Tailscale Network

## Overview

AI Whisperers uses Tailscale for secure VPN connectivity between devices and the VPS.

## Current Devices

| Device | Tailscale IP | OS | Status | Purpose |
|--------|-------------|-----|--------|---------|
| **agentzero** | 100.91.243.120 | Linux | ✅ Online | Primary VPS (72.61.44.159) |
| **PC-Ale** | 100.110.9.12 | Windows | ✅ Online | Ivan's PC |
| **iZt4n7wo7pg57a16w9x87aZ** | 100.123.97.41 | Linux | ✅ Online | Development server (Alibaba Cloud) |

## Deprecated/Removed

| Device | Tailscale IP | Status | Reason |
|--------|-------------|--------|--------|
| **ai-whisperers-server** | 100.69.193.50 | Removed | Duplicate/unused server |
| **srv1396188** | 100.124.222.54 | Offline | Old hostname, now `agentzero` |

## Tailscale Admin

Manage devices at: https://login.tailscale.com/admin/machines

## Quick Commands

```bash
# Check status
tailscale status

# Ping a device
tailscale ping ai-whisperers-server

# SSH to a device
tailscale ssh agentzero

# Update hostname
tailscale set --hostname agentzero
```

## DNS

Tailscale provides MagicDNS. All devices are accessible via:
- `agentzero.tail9cb0c1.ts.net`
- `pc-ale.tail9cb0c1.ts.net`

## Security

- Tailscale is used for secure access to internal services
- All traffic between devices is encrypted
- Access to services like LiteLLM, n8n, Grafana is via Tailscale only
