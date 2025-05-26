#!/bin/bash

# === Configuration ===
LOG_FILE="/tmp/hostapd_dpp.log"
MAC_DIR="/var/www/html/mac"

# === Root check ===
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# === Ensure MAC_DIR exists ===
mkdir -p "$MAC_DIR"

echo "Monitoring $LOG_FILE for EAPOL-4WAY-HS-COMPLETED..."

# === Main loop ===
while true; do
  # read entire log, grep for completion lines, extract MACs
  cat "$LOG_FILE" \
    | grep 'EAPOL-4WAY-HS-COMPLETED' \
    | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' \
    | while read -r raw_mac; do
        # strip colons
        mac_nocolon="${raw_mac//:/}"
        target_file="${MAC_DIR}/${mac_nocolon}.txt"

        # if the pending file exists, remove it
        if [[ -f "$target_file" ]]; then
          sudo rm -f "$target_file" \
            && echo "$(date +'%Y-%m-%d %H:%M:%S') Device $raw_mac connected"
        fi
      done

  # wait a bit before scanning again
  sleep 5
done

