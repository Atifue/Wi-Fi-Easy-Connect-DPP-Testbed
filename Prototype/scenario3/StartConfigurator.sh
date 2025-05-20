#!/bin/bash

# === Variables ===
INTERFACE="wlp0s20f3"
DRIVER="nl80211"
CONF_PATH="/etc/dpp/configurator.conf"
KEY_FILE="/etc/dpp/configuratorkey.hex"
MAC="982cbc7f0431"
CHANNEL="81/6"
LOG_FILE="/tmp/configurator_dpp.log"
SSID="DPPTestAP42"


# === Root-Check ===
if [[ $EUID -ne 0 ]]; then
  echo "Please sudo"
  exit 1
fi

# === User-defined SSID ===
SSID_HEX=$(echo -n $SSID | xxd -p)

# === Read ASN.1 DER Key ===
if [[ ! -f "$KEY_FILE" ]]; then
  echo -e "Error: Key not found. Create it first with CrPrKey.sh\n"
  exit 1
fi

KEY_HEX=$(< "$KEY_FILE")


# === Setup of wpa_supplicant ===
echo -e "Starting wpa_supplicant...\n"
sudo pkill wpa_supplicant 2>/dev/null
sudo ip link set "$INTERFACE" down
sudo rfkill unblock wifi
sleep 1
sudo ip link set "$INTERFACE" up
sudo wpa_supplicant -i "$INTERFACE" -D "$DRIVER" -c "$CONF_PATH" -dd > /tmp/configurator_dpp.log 2>&1 &
sleep 2 # wait for uptime

# === Add Configurator ===
sudo wpa_cli -i "$INTERFACE" dpp_configurator_add key="$KEY_HEX"

# === Remove possible leftover keys from last script execution ===
sudo rm -f /tmp/unconfigured_peers.txt
sudo rm -f /tmp/unconfigured_peers_tmp.txt


# === Big block... Loop to add devices added by store.py on lighttp UI ===
KEY_DIR="/var/www/html/keys" #Location of Keys stored by store.py
UNCONFIGURED_PEERS_FILE="/tmp/unconfigured_peers.txt"

touch "$UNCONFIGURED_PEERS_FILE"

echo "[INFO] Starting DPP peer processing loop..."

while true; do
    # Step 1: Read new bootstrap keys from files in the key directory
	for keyfile in "$KEY_DIR"/key_*.txt; do
    	[ -e "$keyfile" ] || continue
    	KEY=$(cat "$keyfile")

   	echo "[INFO] Found bootstrap key in $keyfile"

    # Extract Peer ID and MAC Address from bootstrapping key
    	PEER_ID=$(sudo wpa_cli -i "$INTERFACE" dpp_qr_code "$KEY" | grep -oP '^\d+')
    	RAW_MAC=$(echo "$KEY" | grep -oP 'M:\K[^;]+')

    	if [ -n "$PEER_ID" ] && [ -n "$RAW_MAC" ]; then
        	echo "[INFO] Added PEER_ID $PEER_ID with MAC $RAW_MAC from $keyfile"
        	echo "$PEER_ID:$RAW_MAC" >> "$UNCONFIGURED_PEERS_FILE"
    	else
        	echo "[WARN] Failed to extract PEER_ID or MAC from $keyfile"
    	fi

    	rm "$keyfile"
	done


    # Step 2: Loop through unconfigured peer IDs and initiate DPP authentication
    if [ -s "$UNCONFIGURED_PEERS_FILE" ]; then
    	TEMP_PEERS_FILE="/tmp/unconfigured_peers_tmp.txt"
    	> "$TEMP_PEERS_FILE"

    	while IFS=":" read -r PEER_ID RAW_MAC; do
        	echo "[INFO] Starting DPP auth init for PEER_ID $PEER_ID (MAC $RAW_MAC)"
        	sudo wpa_cli -i "$INTERFACE" dpp_auth_init peer="$PEER_ID" configurator=1 conf=sta-dpp ssid=$SSID_HEX

        	# formating to make Format of MAC Address suitable for Log Parsing
        	MAC=$(echo "$RAW_MAC" | sed 's/../&:/g; s/:$//')

        	# Waiting for successfull provisioning
        	SUCCESS=0
        	for i in {1..15}; do
            		if grep -q "DPP-RX src=$MAC freq=2437 type=11" "$LOG_FILE"; then #DPP-RX... means: Information(Configuration Confirmation) from source(Enrollee)
                		SUCCESS=1
                		break
            		fi
            		sleep 5
        	done

        	if [ "$SUCCESS" -eq 1 ]; then
            		echo "[SUCCESS] Peer $PEER_ID with Mac Address ($MAC) provisioned"
        	else
            		echo "[INFO] Peer $PEER_ID with Mac Address ($MAC) not reachable, trying again later"
            		echo "$PEER_ID:$RAW_MAC" >> "$TEMP_PEERS_FILE"
        	fi

        	sleep 5
    	done < "$UNCONFIGURED_PEERS_FILE"

    mv "$TEMP_PEERS_FILE" "$UNCONFIGURED_PEERS_FILE"
else
    echo "[INFO] Currently no devices to configure"
fi


    # Wait 30 seconds before the next iteration
    echo "[INFO] Waiting 10 seconds before next check..."
    sleep 10
done

