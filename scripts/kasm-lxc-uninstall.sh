#!/bin/bash
set -e

# ---------------------------------------------------------
#  Kasm Workspaces – One‑Command Proxmox LXC Installer
# ---------------------------------------------------------

# --- Configuration ---
CTID="$1"
DISK_SIZE="60"        # GB
RAM_SIZE="8192"       # MB
SWAP_SIZE="4096"      # MB
CORE_COUNT="4"
KASM_VERSION="1.18.1.0"

# --- Colors ---
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

echo -e "${GREEN}=== Kasm LXC Installer Starting ===${NC}"

# ---------------------------------------------------------
#  Validate CTID
# ---------------------------------------------------------
if [ -z "$CTID" ]; then
  echo -e "${RED}ERROR:${NC} No CTID provided."
  echo "Usage: $0 <CTID>"
  exit 1
fi

# ---------------------------------------------------------
#  Locate Debian 12 Template
# ---------------------------------------------------------
echo -e "${GREEN}=== Checking for Debian 12 template ===${NC}"

TEMPLATE=$(pveam available | awk '/debian-12-standard/ {print $2; exit}')

if [ -z "$TEMPLATE" ]; then
  echo -e "${RED}ERROR:${NC} No Debian 12 template found in pveam available list."
  exit 1
fi

if ! pveam list local | grep -q "$TEMPLATE"; then
  echo -e "${YELLOW}Template not found locally. Downloading $TEMPLATE ...${NC}"
  pveam update
  pveam download local "$TEMPLATE"
fi

# ---------------------------------------------------------
#  Create LXC Container
# ---------------------------------------------------------
echo -e "${GREEN}=== Creating Debian 12 LXC ($CTID) ===${NC}"

pct create "$CTID" local:vztmpl/$TEMPLATE \
  --hostname kasm \
  --cores "$CORE_COUNT" \
  --memory "$RAM_SIZE" \
  --swap "$SWAP_SIZE" \
  --storage local-lvm \
  --rootfs local-lvm:"$DISK_SIZE" \
  --net0 name=eth0,bridge=vmbr0,firewall=1,type=veth \
  --features nesting=1,keyctl=1,fuse=1 \
  --unprivileged 0

pct stop "$CTID"

# ---------------------------------------------------------
#  Apply Kasm Required LXC Config
# ---------------------------------------------------------
CONF="/etc/pve/lxc/$CTID.conf"

echo -e "${GREEN}=== Applying Kasm LXC configuration ===${NC}"

cat <<EOC >> "$CONF"

# --- KASM REQUIRED CONFIG ---
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.cgroup2.devices.allow: a
lxc.cgroup2.devices.allow: c 10:229 rwm
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/fuse dev/fuse none bind,create=file
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
# --- END KASM CONFIG ---
EOC

# ---------------------------------------------------------
#  Ensure Host Devices Exist
# ---------------------------------------------------------
echo -e "${GREEN}=== Ensuring host devices exist ===${NC}"

mkdir -p /dev/net

if [ ! -e /dev/net/tun ]; then
  mknod /dev/net/tun c 10 200
fi
chmod 0666 /dev/net/tun

if [ ! -e /dev/fuse ]; then
  mknod /dev/fuse c 10 229
fi
chmod 0666 /dev/fuse

# ---------------------------------------------------------
#  Start Container
# ---------------------------------------------------------
echo -e "${GREEN}=== Starting container ===${NC}"
pct start "$CTID"
sleep 5

# ---------------------------------------------------------
#  Install Docker
# ---------------------------------------------------------
echo -e "${GREEN}=== Installing Docker inside container ===${NC}"

pct exec "$CTID" -- bash -c "
set -e
apt update
apt install -y curl ca-certificates gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable' > /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
"

# ---------------------------------------------------------
#  Install Kasm Workspaces
# ---------------------------------------------------------
echo -e "${GREEN}=== Installing Kasm Workspaces ($KASM_VERSION) ===${NC}"

pct exec "$CTID" -- bash -c "
set -e
cd /tmp
curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_${KASM_VERSION}.tar.gz
tar -xf kasm_release_${KASM_VERSION}.tar.gz
cd kasm_release
bash kasm_install.sh --accept-eula --swap-size $SWAP_SIZE
"

echo -e "${GREEN}=== Kasm installation complete ===${NC}"
