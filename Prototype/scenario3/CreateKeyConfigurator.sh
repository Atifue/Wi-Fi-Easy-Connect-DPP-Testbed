#!/bin/bash

# === Variables ===
KEY_DIR="/etc/dpp"
KEY_FILE="$KEY_DIR/configuratorkey.hex"
PEM_KEY="$KEY_DIR/configurator.pem"

# === Root-Check ===
if [[ $EUID -ne 0 ]]; then
  echo "Please sudo"
  exit 1
fi

mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

# === EC Private Key Gen ===
echo "Creating EC Private Key"
openssl ecparam -name prime256v1 -genkey -noout -out "$PEM_KEY"

# === Converting  ===
echo "Converting PEM → DER → HEX..."
openssl ec -in "$PEM_KEY" -outform DER | xxd -p | tr -d '\n' > "$KEY_FILE"

chmod 600 "$PEM_KEY" "$KEY_FILE"

echo "DPP Private Key saved as:"
echo "$KEY_FILE"

# === Show Key ===
echo -n "HEX Key: "
head -c 80 "$KEY_FILE"; echo "..."
