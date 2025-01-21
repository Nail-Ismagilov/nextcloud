#!/bin/bash

# Start the WPS process
sudo wpa_cli -i wlan0 wps_pbc

echo "Press the WPS button on your router within 2 minutes."

# Wait for the connection to be established
sleep 120

# Check the connection status
sudo wpa_cli -i wlan0 status

echo "If the connection was successful, the SSID and PSK will be added to /etc/wpa_supplicant/wpa_supplicant.conf"
