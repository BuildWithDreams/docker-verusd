---
name: docker-verusd
description: Dockerized verusd blockchain node management. Run Verus Protocol blockchains (vDEX, VRSC, vRSCTEST, etc.) as Docker containers with compose. Covers container lifecycle, sync management, bootstrap, CLI usage, network provisioning (Ansible), and troubleshooting.
version: 1.1.0
tags: [verus, blockchain, docker, docker-compose, vdex, vrsctest, vrsc, ansible]
related_skills: []
---

# docker-verusd

Dockerized verusd — run Verus Protocol blockchain nodes as Docker containers. Managed via Ansible — see `provisioning/` directory for infrastructure playbooks.

## Repo Structure

```
docker-verusd/
├── Dockerfile              # verusd image definition
├── build.sh                # build script
├── mainnet/                # VRSC main chain
│   ├── docker-compose.yml
│   └── .env
├── pbaas/
│   ├── vdex/               # vDEX chain
│   │   ├── docker-compose.yaml
│   │   └── .env
│   ├── varrr/              # varrr chain
│   └── chips/              # chips chain
├── vrsctest/               # vRSCTEST (testnet)
│   ├── docker-compose.yml
│   └── .env
└── infrastructure/          # Network provisioning
    ├── init_network.sh
    ├── teardown_network.sh
    ├── env.sample
    └── .env.<network>      # per-network env files
```

## Docker Networks

Each chain gets its own Docker bridge network. Networks are defined as Ansible variables and provisioned via `playbooks/03-docker-networks.yml`.

**IP convention per service** (4th octet):
```
.11  verusd daemon
.12  RPC server
.13  block explorer
.14  ID verification service
```

**Network naming:** `net-<chain>-<color>` e.g. `net-vrsc-blue`
**Bridge name:** `br-SP<subnet>` e.g. `br-SP1020101` for `10.201.0.0/24`

### Provision Networks (Ansible)

```bash
# From provisioning/ directory on local machine
cd provisioning
ansible-playbook -i inventory.ini playbooks/03-docker-networks.yml
```

Networks are defined in `provisioning/group_vars/production.yml` under `verus_networks`.

### Create Network Manually

```bash
# 1. Create .env file
cat > infrastructure/.env.net-vrsc-blue <<EOF
DOCKER_NETWORK_SUBNET=10.201.0.0/24
BRIDGE_CUSTOM_NAME=SP1020101
DOCKER_NETWORK_NAME=net-vrsc-blue
EOF

# 2. Create network
bash infrastructure/init_network.sh infrastructure/.env.net-vrsc-blue

# 3. Verify
docker network inspect net-vrsc-blue --format 'Name={{.Name}} Subnet={{range .IPAM.Config}}{{.Subnet}}{{end}}'
```

### Tear Down Network

```bash
bash infrastructure/teardown_network.sh infrastructure/.env.net-vrsc-blue
```

## Chain Configuration Reference

| Chain | Data dir in container | CLI chain param | RPC port | Hex chain ID |
|-------|----------------------|-----------------|----------|--------------|
| vDEX | `/root/.verus/pbaas/<hex>` | `-chain=vdex` | 21778 | `53fe39eea8c06bba32f1a4e20db67e5524f0309d` |
| varrr | `/root/.verus/pbaas/<hex>` | `-chain=varrr` | — | |
| chips | `/root/.verus/pbaas/<hex>` | `-chain=chips` | — | |
| vRSCTEST | `/root/.komodo/vrsctest` | `-chain=vrsctest -testnet` | 18843 | |
| VRSC | `/root/.komodo/VRSC` | (none needed) | — | |

> **PBaaS chains** (vDEX, varrr, chips): data dir is under `/root/.verus/pbaas/<currency_hex_id>`.
> **Non-PBaaS chains** (vRSCTEST, VRSC): data dir is under `/root/.komodo/<CHAINNAME>`.

## Container Lifecycle

### Start a chain
```bash
cd <chain_dir>   # e.g. pbaas/vdex, vrsctest, mainnet
docker-compose up -d
```

### Stop a chain
```bash
cd <chain_dir>
docker-compose stop        # stop, keep data
docker-compose down       # stop and remove container (data dir preserved)
```

### Restart a chain
```bash
cd <chain_dir>
docker-compose restart
# or recreate:
docker-compose up -d      # will recreate if compose file changed
```

### Check status
```bash
docker ps --format "{{.Names}}\t{{.Status}}" | grep <chain>
```

## Sync Status

### Via CLI (inside container)
```bash
docker exec <container_name> verus -chain=<name> getinfo
```

Key fields:
- `blocks` / `longestchain` — current synced height
- `tiptime` — timestamp of last block
- `connections` — peer count
- `VRSCversion` — verusd version
- `progress` in debug.log — sync progress (1.000000 = synced)

### Via debug.log
```bash
docker exec <container_name> tail -f /root/.verus/pbaas/<hex>/debug.log
docker exec <container_name> tail -f /root/.komodo/<chain>/debug.log
```

Look for `UpdateTip: new best=... height=N` for sync progress, `progress=1.000000` for full sync.

## Bootstrap

The `.env` file controls whether to bootstrap or sync from peers:

```
VERUSD_BOOTSTRAP_FLAG=
#VERUSD_BOOTSTRAP_FLAG=-bootstrap
```

| Situation | Flag |
|-----------|------|
| Fresh node, no data | `VERUSD_BOOTSTRAP_FLAG=-bootstrap` |
| Normal sync from peers | `VERUSD_BOOTSTRAP_FLAG=` (empty) |
| Unexpected crash/shutdown | `VERUSD_BOOTSTRAP_FLAG=-bootstrap` (re-download bootstrap to fix corruption) |
| Clean shutdown (Shutdown: done in log) | `VERUSD_BOOTSTRAP_FLAG=` (empty) |

### Important: bootstrap wipes existing chain data
If bootstrap runs on a node with existing synced data, **it will delete and re-download everything**. Check data dirs first:

```bash
# Check if data exists and has blocks:
ls data_dir/blocks/
find data_dir/chainstate -type f | wc -l   # should be > 0 if synced
```

If data dirs are empty but container is running bootstrap, **stop immediately** and switch to empty flag:
```bash
docker-compose stop
# edit .env: VERUSD_BOOTSTRAP_FLAG= (empty)
docker-compose up -d
```

## Verus CLI Usage

All CLI commands run inside the container:

```bash
# Get chain info
docker exec <container> verus -chain=vdex getinfo

# Get block count
docker exec <container> verus -chain=vdex getblockcount

# Get blockchain info (PBaaS)
docker exec <container> verus -chain=vdex getblockchaininfo

# Testnet chains require -testnet flag
docker exec <container> verus -chain=vrsctest -testnet getinfo

# Stop daemon gracefully
docker exec <container> verus -chain=vdex stop
```

## Docker Compose Reference

### Standard PBaaS compose (vDEX example)
```yaml
services:
  vdex:
    image: verustrading/verusd:0.1
    command: verusd -chain=${CHAIN_NAME} ${VERUSD_BOOTSTRAP_FLAG}
    volumes:
      - ./data_dir:/root/.verus/pbaas/${CURRENCYID_HEX}
      - /home/${USER}/.zcash-params:/root/.zcash-params:ro
    networks:
      pbaas_network:
        ipv4_address: ${VERUSD_IPV4}
    stop_grace_period: 2m
```

### Standard non-PBaaS compose (vRSCTEST example)
```yaml
services:
  vrsctest:
    image: verustrading/verusd:0.1
    command: verusd -chain=vrsctest -testnet ${VERUSD_BOOTSTRAP_FLAG} &
    volumes:
      - ./data_dir:/root/.komodo/vrsctest
      - /home/${USER}/.zcash-params:/root/.zcash-params:ro
    networks:
      dev16:
        ipv4_address: ${VERUSD_IPV4}
    stop_grace_period: 2m
```

### Important: `${USER}` variable
The zcash-params volume uses `${USER}`. If `docker-compose` is run with `sudo`, `USER` will be `root`, causing the mount to fail silently. Always run docker-compose as the correct user (not sudo).

## Networks

Each chain runs on its own Docker bridge network:

| Chain | Network name |
|-------|-------------|
| vDEX | `net-vdex-blue` |
| VRSC | `net-vrsc-blue`, `net-vrsc-green` |
| vRSCTEST | `dev199` |
| varrr/chips | `chips_fafstaking` |

Networks must exist before starting containers:
```bash
docker network create <network_name>
```

### Important: `${USER}` variable in compose files
The zcash-params volume mount uses `${USER}`:
```yaml
- /home/${USER}/.zcash-params:/root/.zcash-params:ro
```
**Running `docker-compose` with `sudo` breaks this.** `sudo` resets `USER=root`, so the mount resolves to `/home/root/.zcash-params` (missing) instead of the correct user's path. The container will start but crash silently with "Zcash network parameters not found" error.

- /home/<user>/.zcash-params:/root/.zcash-params:ro
```yaml
- /home/<your-user>/.zcash-params:/root/.zcash-params:ro
```

**Detection:** `docker inspect <container> --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'` shows the wrong source path.

## Network Provisioning

Each chain runs on its own Docker bridge network. Networks are defined by `.env` files and created via the infrastructure scripts.

### Network naming convention
```
net-<chain>-<color>
Examples: net-vrsc-blue, net-vrsc-green, net-vdex-blue, net-varrr-blue
```

### IP octet assignments (per service)
```
.11 = verusd daemon
.12 = RPC server
.13 = block explorer
.14 = ID verification
.15 = notary service
... (enumerable uniformly)
```

### Bridge name convention
Bridge names are derived from the subnet's `.1` address, stripped of dots:
```
10.201.0.0/24 → SP1020101
192.168.16.0/24 → SP192168161
```

### Create a network
```bash
cd docker-verusd/infrastructure

# 1. Create the .env file (copy and edit)
cp env.sample .env.net-vrsc-blue
# Edit: DOCKER_NETWORK_SUBNET, BRIDGE_CUSTOM_NAME, DOCKER_NETWORK_NAME

# 2. Run init script
./init_network.sh .env.net-vrsc-blue

# 3. Verify
docker network inspect net-vrsc-blue
```

### Example .env file
```
DOCKER_NETWORK_SUBNET=10.201.0.0/24
BRIDGE_CUSTOM_NAME=SP1020101
DOCKER_NETWORK_NAME=net-vrsc-blue
```

### Tear down a network
```bash
./teardown_network.sh .env.net-vrsc-blue
```

### Existing networks (reference)
| Network | Chain | Subnet |
|---------|-------|--------|
| net-vrsc-blue | VRSC mainnet | 10.201.0.0/24 |
| net-vrsc-green | VRSC mainnet (failover) | 10.202.0.0/24 |
| net-vdex-blue | vDEX | 10.203.0.0/24 |
| dev199 | vRSCTEST | (from .env) |
| chips_fafstaking | chips | (from .env) |

### Networks must exist before starting containers
```bash
docker network create net-vrsc-blue
```

## Building Images

### Build verusd image
```bash
cd docker-verusd

# Set version in Dockerfile
sed -i 's/VERUS_VERSION=1.2.14-2/VERUS_VERSION=1.2.16/' Dockerfile

# Build
bash build.sh
```

Image: `verustrading/verusd:0.1`

## Troubleshooting

### Container exits immediately after start
```bash
docker-compose logs <service_name>
```

Common causes:
- Missing zcash params mount → `USER` variable wrong (don't use sudo)
- Missing or wrong network → create network first
- Bootstrap in progress → check debug.log

### "not running" from docker-compose exec
The container is stopped. Start it first:
```bash
docker-compose up -d
```

### zcash params not found
Error: `Cannot find the Zcash network parameters`

The mount `/home/${USER}/.zcash-params` is resolving to the wrong path. Ensure:
1. You're not running with `sudo` (which sets USER=root)
2. The source path exists on the host: `ls /home/$USER/.zcash-params/`

### Bootstrap overwrote existing data
If bootstrap was triggered on a node with valid existing data, chain data is wiped. Stop the container immediately:
```bash
docker-compose stop
# Switch VERUSD_BOOTSTRAP_FLAG= (empty) in .env
docker-compose up -d
# It will re-sync from peers (slower than bootstrap but preserves nothing lost)
```

### Wrong IP assigned / container won't start
Usually means the Docker network doesn't exist:
```bash
docker network ls
docker network create <network_name>
```

### Check clean shutdown
```bash
docker exec <container> tail -20 /root/.komodo/<chain>/debug.log
# or for PBaaS:
docker exec <container> tail -20 /root/.verus/pbaas/<hex>/debug.log
```
Look for `Shutdown: done` at the end = clean shutdown. Last `UpdateTip` = last synced block.

### Ansible: `~` does not expand under sudo
When Ansible runs shell tasks with `become: true`, `~` is literal — does not expand to the user's home directory.

```yaml
# Wrong — fails
cmd: bash "~{{ ansible_user }}/path/script.sh"

# Correct — always use absolute paths
cmd: bash "/home/{{ ansible_user }}/path/script.sh"
```

### Ansible: files created as root when become:true
With `become: true`, Ansible writes files as root. Use `owner` and `group` to fix:
```yaml
- ansible.builtin.copy:
    content: "{{ content }}"
    dest: "/home/{{ ansible_user }}/file"
    owner: "{{ ansible_user }}"
    group: "{{ ansible_user }}"
```

### Ansible: template file not found
Ansible's `template` module searches relative to the playbook directory (`playbooks/templates/`), not the project root. Use `ansible.builtin.copy` with inline `content:` to avoid path issues.

## Environment Variables (.env)

| Variable | Purpose |
|----------|---------|
| `COMPOSE_PROJECT_NAME` | Docker compose project name (also used for container naming) |
| `DOCKER_NETWORK_NAME` | External Docker bridge network |
| `CHAIN_NAME` | Chain identifier (PBaaS only) |
| `CURRENCYID_HEX` | PBaaS chain hex ID (PBaaS only) |
| `VERUSD_HOSTNAME` | Container hostname |
| `VERUSD_IPV4` | Static IP on the Docker network |
| `VERUSD_P2P_PORT` | P2P port |
| `VERUSD_RPC_PORT` | RPC port |
| `LOCAL_RPC_PORT` | Host port mapping for VRSC mainnet |
| `VERUSD_BOOTSTRAP_FLAG` | `-bootstrap` or empty |
