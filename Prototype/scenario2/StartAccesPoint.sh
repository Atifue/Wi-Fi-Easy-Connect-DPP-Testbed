#!/bin/bash

# === Variables ===
INTERFACE="wlx00c0cab79230"
DRIVER="nl80211"
CONF_PATH="/etc/dpp/hostapd-ap.conf"
KEY_FILE="/etc/dpp/privatekey.hex"
MAC="00c0cab79230"
CHANNEL="81/6"

# === Root-Check ===
if [[ $EUID -ne 0 ]]; then
  echo "Please sudo"
  exit 1
fi

# === Read ASN.1 DER Key ===
if [[ ! -f "$KEY_FILE" ]]; then
  echo "Error: Key not found. Create it first with CrPrKey.sh"
  exit 1
fi

KEY_HEX=$(< "$KEY_FILE")

# === Starting hostapd-dpp with debug in log ===
echo -e "Starting hostapd-dpp...\n"
sudo pkill hostapd 2>/dev/null
sudo ip link set $INTERFACE down
sudo rfkill unblock wifi
sleep 1
sudo ip link set $INTERFACE up
sudo hostapd-dpp "$CONF_PATH" -dd > /tmp/hostapd_dpp.log 2>&1 &

sleep 2  # wait for uptime
sudo ip addr add 192.168.50.1/24 dev $INTERFACE
sleep 1
# Start dhcp client
sudo systemctl restart dnsmasq
sleep 1

# === Creating Bootstrap with key ===
echo -e "Generating Bootstrap Uri\n"
sudo hostapd_cli-dpp -i "$INTERFACE" dpp_bootstrap_gen \
  type=qrcode \
  key="$KEY_HEX" \
  mac="$MAC" \
  chan="$CHANNEL"

# === Start Listening ===
echo -e "\nSetting Device on DPP_Listen (2437 MHz)..."
sudo hostapd_cli-dpp -i "$INTERFACE" dpp_listen 2437

# === Show URI ===
echo -e "\nHere is your Bootstrap Public Key: \n"
sudo hostapd_cli-dpp -i "$INTERFACE" dpp_bootstrap_get_uri 1
echo -e "\nOr scan this QR Code if possible: \n"
sudo hostapd_cli-dpp -i "$INTERFACE" dpp_bootstrap_get_uri 1 | qrencode -t ansiutf8

# === Wait for incoming DPP and parse connector ===
echo -e "\nWaiting for DPP credentials...\n"

DPP_CONNECTOR=""
DPP_CSIGN=""
DPP_NETACCESSKEY=""

sudo tail -n 0 -f /tmp/hostapd_dpp.log | while read -r line; do
  if [[ "$line" == *"DPP-CONNECTOR "* ]]; then
    DPP_CONNECTOR="${line#*DPP-CONNECTOR }"
    echo -e "[DEBUG] Received DPP Connector (start): ${DPP_CONNECTOR:0:30}...\n"
  elif [[ "$line" == *"DPP-C-SIGN-KEY "* ]]; then
    DPP_CSIGN="${line#*DPP-C-SIGN-KEY }"
    echo -e "[DEBUG] Received DPP C-Sign Key (start): ${DPP_CSIGN:0:30}...\n"
  elif [[ "$line" == *"DPP-NET-ACCESS-KEY "* ]]; then
    DPP_NETACCESSKEY="${line#*DPP-NET-ACCESS-KEY }"
    echo -e "[DEBUG] Received DPP Net Access Key (start): ${DPP_NETACCESSKEY:0:30}...\n"
  fi

  if [[ -n "$DPP_CONNECTOR" && -n "$DPP_CSIGN" && -n "$DPP_NETACCESSKEY" ]]; then
    echo -e "\nAll required DPP credentials received. Applying to hostapd...\n"
    echo -e "[DEBUG] Setting dpp_connector...\n"
    sudo hostapd_cli-dpp -i "$INTERFACE" set dpp_connector "$DPP_CONNECTOR"
    
    echo -e "[DEBUG] Setting dpp_csign...\n"
    sudo hostapd_cli-dpp -i "$INTERFACE" set dpp_csign "$DPP_CSIGN"
    
    echo -e "[DEBUG] Setting dpp_netaccesskey...\n"
    sudo hostapd_cli-dpp -i "$INTERFACE" set dpp_netaccesskey "$DPP_NETACCESSKEY"

    echo -e "\nSuccess. Access Point is now configured. STA can now proceed with DPP join.\n"
    break
  fi
done

sudo hostapd_cli-dpp -i "$INTERFACE" update_beacon

# === Wait for STA to complete 4-way handshake ===
#echo -e "\nWaiting for STA to complete 4-Way Handshake...\n"

#sudo tail -n 0 -f /tmp/hostapd_dpp.log | while read -r line; do
#  if [[ "$line" == *"EAPOL-4WAY-HS-COMPLETED"* ]]; then
#    echo -e "\n4-Way Handshake completed. STA successfully joined the network.\n"
#    break
#  fi
#done

