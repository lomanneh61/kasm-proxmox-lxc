#!/bin/bash
set -e

CTID=$1
if [ -z "$CTID" ]; then
  echo "Usage: $0 <CTID>"
  exit 1
fi

pct exec $CTID -- bash -c "
echo 'Stopping all Kasm containers...'
docker ps -a --format '{{.Names}}' | grep kasm | xargs -r docker stop

echo 'Removing all Kasm containers...'
docker ps -a --format '{{.Names}}' | grep kasm | xargs -r docker rm -f

echo 'Removing Kasm networks...'
docker network rm kasm_default_network 2>/dev/null || true

echo 'Removing rclone plugin...'
docker plugin disable rclone/docker-volume-rclone 2>/dev/null || true
docker plugin rm rclone/docker-volume-rclone 2>/dev/null || true

echo 'Removing Kasm install directory...'
rm -rf /opt/kasm /var/lib/kasm /usr/local/bin/kasm*

echo 'Removing Kasm Docker images...'
docker images | grep kasm | awk '{print \$3}' | xargs -r docker rmi -f

echo 'Removing leftover volumes...'
docker volume ls | grep kasm | awk '{print \$2}' | xargs -r docker volume rm

echo 'Kasm uninstallation complete.'
"
