#!/bin/bash
set -e

CTID=$1
NOTIFY_TYPE=$2
NOTIFY_TARGET=$3

if [ -z "$CTID" ]; then
  echo "Usage: $0 <CTID> [--notify-email address | --notify-discord webhook | --notify-telegram token:chatid | --notify-none]"
  exit 1
fi

LOGFILE="/root/kasm-update.log"

notify() {
  MESSAGE="$1"

  case "$NOTIFY_TYPE" in
    --notify-email)
      echo "$MESSAGE" | mail -s "Kasm Update Notification" "$NOTIFY_TARGET"
      ;;
    --notify-discord)
      curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$MESSAGE\"}" "$NOTIFY_TARGET"
      ;;
    --notify-telegram)
      TOKEN=$(echo "$NOTIFY_TARGET" | cut -d: -f1)
      CHATID=$(echo "$NOTIFY_TARGET" | cut -d: -f2-)
      curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHATID" \
        -d text="$MESSAGE" >/dev/null
      ;;
    *)
      ;;
  esac
}

echo "=== Detecting installed Kasm version inside container $CTID ===" | tee -a "$LOGFILE"
INSTALLED=$(pct exec $CTID -- bash -c "cat /opt/kasm/current/version.txt 2>/dev/null" | tr -d '\r')

if [ -z "$INSTALLED" ]; then
  echo "Could not detect installed version. Is Kasm installed?" | tee -a "$LOGFILE"
  exit 1
fi

echo "Installed version: $INSTALLED" | tee -a "$LOGFILE"

echo "=== Fetching latest Kasm version ===" | tee -a "$LOGFILE"
LATEST=$(curl -s https://kasm-static-content.s3.amazonaws.com/ | grep -oP 'kasm_release_\K[0-9\.]+' | sort -V | tail -n 1)

if [ -z "$LATEST" ]; then
  echo "Could not detect latest version." | tee -a "$LOGFILE"
  exit 1
fi

echo "Latest available version: $LATEST" | tee -a "$LOGFILE"

if dpkg --compare-versions "$INSTALLED" ge "$LATEST"; then
  echo "Kasm is already up to date." | tee -a "$LOGFILE"
  notify "Kasm is already up to date (version $INSTALLED)."
  exit 0
fi

echo "=== Updating Kasm from $INSTALLED to $LATEST ===" | tee -a "$LOGFILE"
notify "Updating Kasm from $INSTALLED to $LATEST on container $CTID."

pct exec $CTID -- bash -c "
set -e
echo 'Stopping Kasm containers...' | tee -a $LOGFILE
docker ps -a --format '{{.Names}}' | grep kasm | xargs -r docker stop

echo 'Backing up current install...' | tee -a $LOGFILE
mkdir -p /opt/kasm_backup
cp -r /opt/kasm /opt/kasm_backup/kasm_\$(date +%F_%H-%M-%S)

echo 'Downloading release $LATEST...' | tee -a $LOGFILE
curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_${LATEST}.tar.gz
tar -xf kasm_release_${LATEST}.tar.gz
cd kasm_release

echo 'Running upgrade script...' | tee -a $LOGFILE
bash kasm_upgrade.sh --accept-eula

echo 'Cleaning up installer files...' | tee -a $LOGFILE
cd ..
rm -rf kasm_release kasm_release_${LATEST}.tar.gz

echo 'Restarting Kasm services...' | tee -a $LOGFILE
docker ps -a --format '{{.Names}}' | grep kasm | xargs -r docker start
"

echo "=== Checking container health ===" | tee -a "$LOGFILE"
pct exec $CTID -- docker ps | tee -a "$LOGFILE"

echo "=== Kasm successfully updated to $LATEST ===" | tee -a "$LOGFILE"
notify "Kasm successfully updated to version $LATEST on container $CTID."
