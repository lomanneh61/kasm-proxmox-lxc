#!/bin/bash
set -e

CTID=$1
if [ -z "$CTID" ]; then
  echo "Usage: $0 <CTID>"
  exit 1
fi

echo "=== Checking for Debian 12 template ==="
TEMPLATE=$(pveam available | awk '/debian-12-standard/ {print $2; exit}')

if [ -z "$TEMPLATE" ]; then
  echo "ERROR: No Debian 12 template found in pveam available list."
  exit 1
fi

if ! pveam list local | grep -q "$TEMPLATE"; then
  echo "Template not found locally. Downloading $TEMPLATE ..."
  pveam update
  pveam download local "$TEMPLATE"
fi

pct create $CTID local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname kasm \
  --cores 4 \
  --memory 8192 \
  --swap 4096 \
  --storage local-lvm \
  --rootfs local-lvm:32 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,type=veth \
  --features nesting=1,keyctl=1,fuse=1 \
  --unprivileged 0

pct stop $CTID

CONF="/etc/pve/lxc/$CTID.conf"

cat <<EOC >> "$CONF"

# --- KASM REQUIRED CONFIG ---
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.cgroup2.devices.allow: c 10:229 rwm
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/fuse dev/fuse none bind,create=file
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
lxc.cgroup2.devices.allow: a
# --- END KASM CONFIG ---
EOC

echo "=== Ensuring host devices exist ==="
mkdir -p /dev/net
[ ! -e /dev/net/tun ] && mknod /dev/net/tun c 10 200
chmod 0666 /dev/net/tun
[ ! -e /dev/fuse ] && mknod /dev/fuse c 10 229
chmod 0666 /dev/fuse

echo "=== Starting container ==="
pct start $CTID
sleep 5

echo "=== Installing Docker inside container ==="
pct exec $CTID -- bash -c "
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

echo "=== Installing Kasm Workspaces ==="
pct exec $CTID -- bash -c "
set -e
curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_1.18.1.0.tar.gz
tar -xf kasm_release_1.18.1.0.tar.gz
cd kasm_release
bash kasm_install.sh --accept-eula --swap-size 4096
"

echo "=== Kasm installation complete ==="
