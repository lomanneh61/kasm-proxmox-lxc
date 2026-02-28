Kasm Workspaces on Proxmox LXC

A complete automation suite for installing, updating, and managing Kasm Workspaces inside a Debian 12 privileged LXC container on Proxmox VE.

This project provides:



One‑command installer



One‑command uninstaller



Auto‑update script with email, Discord, or Telegram notifications



Optional systemd timer for nightly updates



Optional Proxmox GUI button for one‑click updates



Clean, reproducible LXC configuration compatible with Docker and Kasm



Installation

Kasm can be installed into any CTID you choose.



Install into a specific CTID

bash

bash scripts/kasm-lxc-installer.sh <CTID>

Example:



bash

bash scripts/kasm-lxc-installer.sh 200

Automatically use the next available CTID

bash

NEXT=$(pvesh get /cluster/nextid)

bash scripts/kasm-lxc-installer.sh $NEXT

The installer will:



Create a Debian 12 privileged LXC



Apply all required Kasm/Docker LXC settings



Install Docker



Install Kasm Workspaces



Validate device passthrough (/dev/fuse, /dev/net/tun)



Updating Kasm

The update script automatically detects:



The installed Kasm version



The latest available Kasm release



Whether an upgrade is needed



Update with no notifications

bash

bash scripts/kasm-lxc-auto-update.sh <CTID> --notify-none

Update with email notification

bash

bash scripts/kasm-lxc-auto-update.sh <CTID> --notify-email you@example.com

Update with Discord webhook notification

bash

bash scripts/kasm-lxc-auto-update.sh <CTID> --notify-discord https://discord.com/api/webhooks/XXXX/YYYY

Update with Telegram notification

bash

bash scripts/kasm-lxc-auto-update.sh <CTID> --notify-telegram BOT\_TOKEN:CHAT\_ID

The updater performs:



Graceful shutdown of Kasm containers



Backup of /opt/kasm



Download and extraction of the latest release



In‑place upgrade



Cleanup and health checks



Uninstalling Kasm

To remove Kasm completely from a container:



bash

bash scripts/kasm-lxc-uninstall.sh <CTID>

This removes:



All Kasm containers



All Kasm Docker images



Kasm networks and volumes



rclone plugin



/opt/kasm and related directories



Optional: Nightly Auto‑Update (systemd)

To enable nightly updates at 03:00:



bash

cp systemd/kasm-update.service /etc/systemd/system/

cp systemd/kasm-update.timer /etc/systemd/system/

systemctl enable --now kasm-update.timer

Edit the service file to set your preferred CTID and notification method.



Optional: Proxmox GUI Integration

A one‑click “Update Kasm” button can be added to the Proxmox LXC menu.



Instructions are in:



Code

proxmox-gui/kasm-update-menu.md

This integrates with the wrapper script:



Code

scripts/kasm-lxc-gui-wrapper.sh

Notifications

Documentation for each notification method is included:



notifications/email.md



notifications/discord.md



notifications/telegram.md



Repository Structure

Code

kasm-proxmox-lxc/

├─ scripts/

│  ├─ kasm-lxc-installer.sh

│  ├─ kasm-lxc-uninstall.sh

│  ├─ kasm-lxc-auto-update.sh

│  ├─ kasm-lxc-gui-wrapper.sh

├─ systemd/

│  ├─ kasm-update.service

│  ├─ kasm-update.timer

├─ proxmox-gui/

│  ├─ kasm-update-menu.md

├─ notifications/

│  ├─ telegram.md

│  ├─ discord.md

│  ├─ email.md

└─ README.md

Requirements

Proxmox VE 7 or 8



Debian 12 LXC template



Privileged container



Features: nesting=1, keyctl=1, fuse=1



Storage with enough space for Kasm images (40–80 GB recommended)



License

MIT License.

Use, modify, and contribute freely.

