#!/bin/bash

# === Variables ===
INTERFACE="wlp0s20f3"
DRIVER="nl80211"
CONF_PATH="/etc/dpp/configurator.conf"
KEY_FILE="/etc/dpp/configuratorkey.hex"
MAC="982cbc7f0431"
CHANNEL="81/6"
SSID="DPPTestAP26"


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

# === Get DPP URI from STA ===
STA_URI=$(< /etc/dpp/STA.txt)
echo -e "Reading URI for STA...\n"

#=== Add Bootstrappign Key and Save ID ===
PEER_ID=$(sudo wpa_cli -i "$INTERFACE" dpp_qr_code "$STA_URI")
echo "Received peer ID: $PEER_ID"

# === Push Connector to STA ===
echo -e "Starting STA provisioning with DPP...\n"
sudo wpa_cli -i "$INTERFACE" dpp_auth_init peer=$PEER_ID configurator=1 conf=sta-dpp ssid=$SSID_HEX

echo -e "\nDPP Configuration complete."


