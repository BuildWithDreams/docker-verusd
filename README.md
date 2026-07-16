# verusd

Dockerized verusd — run Verus Protocol blockchain nodes as containers.

Built to image `verustrading/verusd:0.1`. Update `VERUS_VERSION` in the Dockerfile when new releases are announced.

Requires Zcash params mounted read-only from host:
```
/home/<user>/.zcash-params:/root/.zcash-params:ro
```

> ⚠️ **Important:** The zcash-params volume uses `${USER}`. If docker-compose runs with `sudo`, `USER` becomes `root` and the mount silently fails. Always run docker-compose as the correct user.

## Infrastructure

### Docker Networks

Each chain gets its own Docker bridge network. Networks are defined in `infrastructure/` and provisioned via Ansible.

**IP convention per service** (4th octet):
```
.11  verusd daemon
.12  RPC server
.13  block explorer
.14  ID verification service
```

**Network naming:**
```
net-<chain>-<color>   e.g. net-vrsc-blue, net-vdex-green
```

**Bridge name convention:**
```
br-SP<subnet>   e.g. br-SP1020101 for 10.201.0.0/24
```

### Setup via Ansible

```bash
# 1. Provision networks via Ansible
cd provisioning
ansible-playbook -i inventory.ini playbooks/03-docker-networks.yml

# 2. Verify
docker network ls | grep net-
docker network inspect net-vrsc-blue
```

### Manual network creation (without Ansible)

```bash
# Create .env file
cat > infrastructure/.env.net-vrsc-blue <<EOF
DOCKER_NETWORK_SUBNET=10.201.0.0/24
BRIDGE_CUSTOM_NAME=SP1020101
DOCKER_NETWORK_NAME=net-vrsc-blue
EOF

# Create network
bash infrastructure/init_network.sh infrastructure/.env.net-vrsc-blue

# Verify
docker network inspect net-vrsc-blue --format 'Name={{.Name}} Subnet={{range .IPAM.Config}}{{.Subnet}}{{end}}'
```

## Chain Configurations

| Chain | Data dir | CLI chain param | Notes |
|-------|----------|-----------------|-------|
| vDEX | `/root/.verus/pbaas/<hex>` | `-chain=vdex` | PBaaS, hex ID: `53fe39eea8c06bba32f1a4e20db67e5524f0309d` |
| vRSCTEST | `/root/.komodo/vrsctest` | `-chain=vrsctest -testnet` | Testnet |
| VRSC | `/root/.komodo/VRSC` | (none) | Mainnet |

## Bootstrap

In each chain's `.env`:
```
VERUSD_BOOTSTRAP_FLAG=-bootstrap   # download fresh
VERUSD_BOOTSTRAP_FLAG=             # sync from peers
```

Use `-bootstrap` for fresh nodes or after crashes. Empty flag to sync from peers using existing data.

## Quick Start

```bash
# VRSC mainnet
cd mainnet
docker-compose up -d

# vRSCTEST
cd vrsctest
docker-compose up -d

# vDEX
cd pbaas/vdex
docker-compose up -d
```

## Verus CLI

```bash
# Get info
docker exec <container> verus -chain=vdex getinfo

# Testnet requires -testnet flag
docker exec <container> verus -chain=vrsctest -testnet getinfo

# Stop gracefully
docker exec <container> verus -chain=vdex stop
```

## Sync Status

```bash
docker exec <container> verus -chain=vdex getinfo | grep -E '"blocks"|"connections"|"VRSCversion"'
docker exec <container> tail -5 /root/.verus/pbaas/<hex>/debug.log
```

Look for `progress=1.000000` in debug.log = fully synced.

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `DOCKER_NETWORK_NAME` | Docker network name |
| `DOCKER_NETWORK_SUBNET` | CIDR subnet |
| `BRIDGE_CUSTOM_NAME` | Bridge name prefix (br-SP + suffix) |
| `VERUSD_BOOTSTRAP_FLAG` | `-bootstrap` or empty |
| `VERUSD_IPV4` | Static IP on network (e.g. `10.201.0.11`) |
