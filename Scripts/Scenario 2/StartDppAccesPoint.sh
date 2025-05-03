#!/bin/bash

# === Variables ===
INTERFACE="wlx00c0cab79230"
DRIVER="nl80211"
CONF_PATH="/etc/dpp/hostapd-ap.conf"
KEY_FILE_AP="/etc/dpp/privatekey.hex"
KEY_FILE_Conf="/etc/dpp/configuratorkey.hex"
MAC="00c0cab79230"
SSID="DPPTestAP7"
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

KEY_HEX_Conf=$(< "$KEY_FILE_Conf")

# === ssid to hex ===
SSID_HEX=$(echo -n $SSID | xxd -p)

# === Starting hostapd-dpp with debug in log ===
echo -e "Starting hostapd-dpp...\n"
sudo pkill hostapd 2>/dev/null
sudo ip link set wlx00c0cab79230 down
sudo rfkill unblock wifi
sleep 1
sudo ip link set wlx00c0cab79230 up
sudo hostapd-dpp "$CONF_PATH" -dd > $LOG_FILE 2>&1 &

sleep 2  # wait for uptime
sudo ip addr add 192.168.50.1/24 dev wlx00c0cab79230
sleep 1
sudo systemctl restart dnsmasq
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

# === Work in Progress ===
echo -e "\nEverything seems to work. Here is a CLI for further development:\n \n"
sudo hostapd_cli-dpp -i "$INTERFACE"

