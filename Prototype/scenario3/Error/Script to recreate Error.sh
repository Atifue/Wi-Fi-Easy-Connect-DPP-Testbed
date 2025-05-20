#!/bin/bash

# === Variables ===
INTERFACE="wlx00c0cab79230"
DRIVER="nl80211"
CONF_PATH="/etc/dpp/hostapd-ap.conf"
KEY_FILE_AP="/etc/dpp/privatekey.hex"
KEY_FILE_Conf="/etc/dpp/configuratorkey.hex"
MAC="00c0cab79230"
SSID="DPPTestAP43"
LOG_FILE="/tmp/hostapd_dpp.log"
CHANNEL="81/6"


# === Root-Check ===
if [[ $EUID -ne 0 ]]; then
  echo "Please sudo"
  exit 1
fi

# === Read ASN.1 DER Key ===
if [[ ! -f "$KEY_FILE_AP" ]]; then
  echo "Error: Key not found. Create it first with CrPrKey.sh"
  exit 1
fi

KEY_HEX_AP=$(< "$KEY_FILE_AP")

# === Read ASN.1 DER Key Configurator ===
if [[ ! -f "$KEY_FILE_Conf" ]]; then
  echo "Error: Key not found. Create it first with CrPrKey.sh"
  exit 1
fi
sudo echo "n" > $LOG_FILE
KEY_HEX_Conf=$(< "$KEY_FILE_Conf")

# === ssid to hex ===
SSID_HEX=$(echo -n $SSID | xxd -p)

# === Starting hostapd-dpp with debug in log ===
echo -e "Starting hostapd-dpp...\n"
sudo pkill hostapd 2>/dev/null
sudo ip link set $INTERFACE down
sudo rfkill unblock wifi
sleep 1
sudo ip link set $INTERFACE up
sudo hostapd-dpp "$CONF_PATH" -dd > $LOG_FILE 2>&1 &

sleep 2  # wait for uptime
sudo ip addr add 192.168.50.1/24 dev $INTERFACE
sleep 1
sudo systemctl restart dnsmasq
sudo systemctl restart lighttpd
sleep 1

# === Creating Bootstrap with key ===
echo -e "Generating Bootstrap Uri\n"
sudo hostapd_cli-dpp -i "$INTERFACE" dpp_bootstrap_gen \
  type=qrcode \
  key="$KEY_HEX_AP" \
  mac="$MAC" \
  chan="$CHANNEL"

# === Start Listening ===
echo -e "\nSetting Device on DPP_Listen (2437 MHz)..."
sudo hostapd_cli-dpp -i "$INTERFACE" dpp_listen 2437

# === Show URI ===
echo -e "\nHere is your Bootstrap Public Key: \n"
sudo hostapd_cli-dpp -i "$INTERFACE" dpp_bootstrap_get_uri 1
echo -e "\nOr scan this QR Code if possible: \n"
sudo hostapd_cli-dpp -i "$INTERFACE" dpp_bootstrap_get_uri 1 | qrencode -t ansiutf8\

# === Creating Configurator ===
echo -e "Starting Configurator Setup\n"
sudo hostapd_cli-dpp -i "$INTERFACE" dpp_configurator_add key="$KEY_HEX_Conf"
sudo hostapd_cli-dpp -i "$INTERFACE" dpp_configurator_sign conf=ap-dpp configurator=1 ssid=$SSID_HEX




# === Wait for incoming DPP and parse connector ===
echo -e "\nWaiting for DPP credentials...\n"
sleep 1

LAST_LOG=$(tail -n 200 "$LOG_FILE")

DPP_CONNECTOR=$(echo "$LAST_LOG" | grep "DPP-CONNECTOR " | tail -n1 | sed 's/^.*DPP-CONNECTOR *//')
# echo -e "[DEBUG] Received DPP Connector (start): \n$DPP_CONNECTOR\n"
DPP_CSIGN=$(echo "$LAST_LOG" | grep "DPP-C-SIGN-KEY " | tail -n1 | sed 's/^.*DPP-C-SIGN-KEY *//')
# echo -e "[DEBUG] Received DPP C-Sign Key (start): \n$DPP_CSIGN\n"
DPP_NETACCESSKEY=$(echo "$LAST_LOG" | grep "DPP-NET-ACCESS-KEY " | tail -n1 | sed 's/^.*DPP-NET-ACCESS-KEY *//')
# echo -e "[DEBUG] Received DPP Net Access Key (start): \n$DPP_NETACCESSKEY\n"

if [[ -n "$DPP_CONNECTOR" && -n "$DPP_CSIGN" && -n "$DPP_NETACCESSKEY" ]]; then
  echo -e "\nAll required DPP credentials received. Applying to hostapd...\n"
  echo -e "[DEBUG] Setting dpp_connector...\n"
  sudo hostapd_cli-dpp -i "$INTERFACE" set dpp_connector $DPP_CONNECTOR
    
  echo -e "[DEBUG] Setting dpp_csign...\n"
  sudo hostapd_cli-dpp -i "$INTERFACE" set dpp_csign $DPP_CSIGN
    
  echo -e "[DEBUG] Setting dpp_netaccesskey...\n"
  sudo hostapd_cli-dpp -i "$INTERFACE" set dpp_netaccesskey $DPP_NETACCESSKEY

  echo -e "\nSuccess. Access Point is now configured. STA can now proceed with DPP join.\n"
else
  echo -e "\nError, DPP Connector Data Missing"
  exit 1
fi

# === Load Connector Configs ===
sudo hostapd_cli-dpp -i "$INTERFACE" update_beacon






# === DPP Peer Key Processing and Auth Loop ===

KEY_DIR="/var/www/html/keys"
UNCONFIGURED_PEERS_FILE="/tmp/unconfigured_peers.txt"

touch "$UNCONFIGURED_PEERS_FILE"

echo "[INFO] Starting DPP peer processing loop..."

while true; do
    # Step 1: Read new bootstrap keys from files in the key directory
    for keyfile in "$KEY_DIR"/key_*.txt; do
        [ -e "$keyfile" ] || continue
        KEY=$(cat "$keyfile")

        echo "[INFO] Found bootstrap key in $keyfile"

        # Extract peer ID using hostapd_cli-dpp
        PEER_ID=$(sudo hostapd_cli-dpp -i "$INTERFACE" dpp_qr_code "$KEY" | grep -oP '^\d+')
        if [ -n "$PEER_ID" ]; then
            echo "[INFO] Added PEER_ID $PEER_ID from $keyfile"
            echo "$PEER_ID" >> "$UNCONFIGURED_PEERS_FILE"
        else
            echo "[WARN] Failed to get PEER_ID from key in $keyfile"
        fi

        # Remove the key file after processing
        rm "$keyfile"
    done

    # Step 2: Loop through unconfigured peer IDs and initiate DPP authentication
    if [ -s "$UNCONFIGURED_PEERS_FILE" ]; then
        TEMP_PEERS_FILE="/tmp/unconfigured_peers_tmp.txt"
        > "$TEMP_PEERS_FILE"

        while read -r PEER_ID; do
            echo "[INFO] Starting DPP auth init for PEER_ID $PEER_ID"
            sudo hostapd_cli-dpp -i "$INTERFACE" dpp_auth_init peer="$PEER_ID" configurator=1 conf=sta-dpp ssid=$SSID_HEX

            # Wait up to 10 seconds for DPP-AUTH-SUCCESS log entry
            SUCCESS=0
            for i in {1..10}; do
                if grep -q "DPP-AUTH-SUCCESS.*peer=$PEER_ID" "$LOG_FILE"; then
                    SUCCESS=1
                    break
                fi
                sleep 1
            done

            if [ "$SUCCESS" -eq 1 ]; then
                echo "[SUCCESS] Auth completed for PEER_ID $PEER_ID"
            else
                echo "[INFO] Auth not successful for PEER_ID $PEER_ID, keeping it for next round"
                echo "$PEER_ID" >> "$TEMP_PEERS_FILE"
            fi

            # Wait 10 seconds before next auth attempt
            sleep 10
        done < "$UNCONFIGURED_PEERS_FILE"

        # Replace the peer list with only those that still need configuration
        mv "$TEMP_PEERS_FILE" "$UNCONFIGURED_PEERS_FILE"
    else
        echo "[INFO] No unconfigured peers at the moment."
    fi

    # Wait 30 seconds before the next iteration
    echo "[INFO] Waiting 30 seconds before next check..."
    sleep 30
done


