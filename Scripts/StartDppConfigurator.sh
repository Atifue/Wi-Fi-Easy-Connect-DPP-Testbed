#!/bin/bash

# === Variables ===
INTERFACE="wlp0s20f3"
DRIVER="nl80211"
CONF_PATH="/etc/dpp/configurator.conf"
KEY_FILE="/etc/dpp/configuratorkey.hex"
MAC="982cbc7f0431"
CHANNEL="81/6"
SSID="DPPTestAP2"


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

# === Starting wpa_supplicant with debug in log ===
echo -e "Starting wpa_supplicant...\n"
sudo pkill wpa_supplicant 2>/dev/null
sudo ip link set "$INTERFACE" down
sleep 1
sudo ip link set "$INTERFACE" up
sudo wpa_supplicant -i "$INTERFACE" -D "$DRIVER" -c "$CONF_PATH" -dd > /tmp/configurator_dpp.log 2>&1 &

sleep 2  # wait for uptime

# === Creating Configurator ===
echo -e "Starting Configurator Setup\n"
sudo wpa_cli -i "$INTERFACE" dpp_configurator_add key="$KEY_HEX"

# === Get DPP URI from AP ===
echo -e "\nEnter DPP URI from Access Point:\n"
read DPP_URI_AP
echo -e "Reading URI for Access Point...\n"
sudo wpa_cli -i "$INTERFACE" dpp_qr_code $DPP_URI_AP

# === Get DPP URI from STA ===
echo -e "\nEnter DPP URI from STA:\n"
read DPP_URI_STA
echo -e "Reading URI for STA...\n"
sudo wpa_cli -i "$INTERFACE" dpp_qr_code $DPP_URI_STA

# === Check AP Ready ===
echo -e "\nIs the Access Point ready for configuration? (yes/no):\n"
read AP_READY
if [[ "$AP_READY" != "yes" ]]; then
  echo -e "Aborting – Access Point not ready.\n"
  exit 1
fi

# === Push Connector to AP ===
echo -e "Starting AP provisioning with DPP...\n"
sudo wpa_cli -i "$INTERFACE" dpp_auth_init peer=1 configurator=1 conf=ap-dpp ssid=$SSID_HEX

# === Check if STA and Connector Ready ===
echo -e "\nHas the Access Point set up the connector and is the STA ready? (yes/no):\n"
read STA_READY
if [[ "$STA_READY" != "yes" ]]; then
  echo -e "Aborting – STA not ready or AP missing connector.\n"
  exit 1
fi

# === Push Connector to STA ===
echo -e "Starting STA provisioning with DPP...\n"
sudo wpa_cli -i "$INTERFACE" dpp_auth_init peer=2 configurator=1 conf=sta-dpp ssid=$SSID_HEX

echo -e "\nDPP Configuration complete."

