#!/bin/bash

set -euo pipefail

# --- ROOT CHECK ---
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo." >&2
  exit 1
fi

# --- INTERFACE SELECTION ---
IFACE="${1:-wlan0}"

# --- CHECK FOR WPA_CLI ---
if ! command -v wpa_cli >/dev/null 2>&1; then
  echo "wpa_cli not found. Please install wpa_supplicant package." >&2
  exit 1
fi

# --- CHECK FOR WPA_SUPPLICANT ---
if ! pgrep -x wpa_supplicant >/dev/null; then
  echo "wpa_supplicant is not running. Please start it before running this script." >&2
  exit 1
fi

# --- CHECK IF INTERFACE EXISTS ---
if ! ip link show "$IFACE" >/dev/null 2>&1; then
  echo "Wireless interface $IFACE not found." >&2
  exit 1
fi

# --- START WPS PROCESS ---
echo "Starting WPS push button configuration on $IFACE..."
wpa_cli -i "$IFACE" wps_pbc

if [ $? -ne 0 ]; then
  echo "Failed to initiate WPS on $IFACE." >&2
  exit 1
fi

echo "Press the WPS button on your router within 2 minutes."
sleep 120

# --- CHECK CONNECTION STATUS ---
STATUS_OUTPUT=$(wpa_cli -i "$IFACE" status)
echo "$STATUS_OUTPUT"

if echo "$STATUS_OUTPUT" | grep -q '^wpa_state=COMPLETED'; then
  echo "Wi-Fi connection established successfully!"
  SSID=$(echo "$STATUS_OUTPUT" | grep '^ssid=' | cut -d= -f2)
  echo "Connected to SSID: $SSID"
  echo "Check /etc/wpa_supplicant/wpa_supplicant.conf for the saved network credentials."
else
  echo "Wi-Fi connection was NOT established. Please try again or check your router and interface." >&2
  exit 1
fi
