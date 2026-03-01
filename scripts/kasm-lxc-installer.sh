#!/bin/bash
set -e

# ---------------------------------------------------------
#  Kasm Workspaces – One‑Command Proxmox LXC Installer
#  Clean, production‑ready version
# ---------------------------------------------------------

# --- Configuration ---
CTID="$1"
DISK_SIZE="60"
RAM_SIZE="8192"
SWAP_SIZE="4096"
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
  echo -e "${RED}ERROR:${NC} No Debian
