#!/bin/bash
set -e

# --- Configuration ---
# Increasing disk to 60GB because Kasm 1.18 seeds large images
DISK_SIZE="60" 
CORE_COUNT="4"
RAM_SIZE="8192"
SWAP_SIZE="4096"
KASM_VERSION="1.18.1.0"

echo "=== Checking for Debian 12 template ==="
TEMPLATE=$(pveam available | awk '/debian-12-standard/ {print $2; exit}')

if [ -z "$TEMPLATE" ]; then
  echo "ERROR: No Debian 12 template found."
  exit 1
fi

if ! pveam list local | grep -q "$TEMPLATE"; then
  echo "Downloading $TEMPLATE ..."
  pveam update
  pveam download local "$TEMPLATE"
fi

CTID=$1
if [ -z "$CTID" ]; then
  echo "Usage: $0 <CTID>"
  exit 1
fi

echo "=== Creating Unprivileged Debian 12 LXC ($CTID) ==="
# Switched to --unprivileged 1 for better security
pct create $CTID local:vztmpl/$TEMPLATE \
  --hostname kasm \
  --cores $CORE_COUNT \
  --memory $RAM_SIZE \
  --swap $SWAP_SIZE \
  --storage local-lvm \
  --rootfs local-lvm:$DISK_SIZE \
  --net0 name=eth0,bridge=vmbr0,firewall=1,type=veth \
  --features nesting=1,keyctl=1,fuse=1 \
  --unprivileged 1

echo "=== Applying Secure Device Passthrough ==="
CONF="/etc/pve/lxc/$CTID.conf"
cat <<EOC >> "$CONF"

# --- KASM REQUIRED CONFIG ---
# Removed 'allow: a' for security; only allowing FUSE and TUN
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.mount.entry: /dev/fuse dev/fuse none bind,create=file
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.cgroup2.devices.allow: c 10:229 rwm
# --- END KASM CONFIG ---
EOC

echo "=== Starting container ==="
pct start $CTID
sleep 5

echo "=== Installing Docker inside container ==="
# Updated to use modern Docker GPG paths
pct exec $CTID -- bash -c "
  apt update && apt install -y curl ca-certificates gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable\" > /etc/apt/sources.list.d/docker.list
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
"

echo "=== Installing Kasm Workspaces ($KASM_VERSION) ==="
pct exec $CTID -- bash -c "
  set -e
  cd /tmp
  curl -O https://kasm-static-content.s3.amazonaws.com
  tar -xf kasm_release_$KASM_VERSION.tar.gz
  cd kasm_release
  # Using $SWAP_SIZE from host config
  bash kasm_install.sh --accept-eula --swap-size $SWAP_SIZE
"

echo "=== Kasm installation complete ==="
