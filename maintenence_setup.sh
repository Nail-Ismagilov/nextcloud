#!/bin/bash

set -euo pipefail

# --- ROOT CHECK ---
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo." >&2
  exit 1
fi

# --- CONFIGURATION ---
NEXTCLOUD_PATH="/var/www/nextcloud"
CONFIG_FILE="$NEXTCLOUD_PATH/config/config.php"
OCC="$NEXTCLOUD_PATH/occ"

# --- CHECKS ---
if [ ! -f "$CONFIG_FILE" ]; then
  echo "config.php file not found at $CONFIG_FILE" >&2
  exit 1
fi
if [ ! -f "$OCC" ]; then
  echo "Nextcloud occ command not found at $OCC" >&2
  exit 1
fi

# --- BACKUP CONFIG ---
cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
echo "Backup of config.php created."

# --- DETECT PHP VERSION ---
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

# --- MAINTENANCE WINDOW ---
sed -i "/);/i 'maintenance_window_start' => 1," "$CONFIG_FILE"
echo "Added 'maintenance_window_start' => 1 to $CONFIG_FILE"

# --- ADD MISSING INDICES ---
sudo -u www-data php "$OCC" db:add-missing-indices
echo "Missing indices added."

# --- RESTART REDIS ---
systemctl restart redis-server

# --- REDIS CONFIGURATION ---
sed -i "/);/i 'memcache.local' => '\\OC\\Memcache\\Redis',\n  'memcache.locking' => '\\OC\\Memcache\\Redis',\n  'redis' => [\n    'host' => 'localhost',\n    'port' => 6379,\n  ]," "$CONFIG_FILE"
echo "Redis configuration added to $CONFIG_FILE."

# --- INSTALL PHP GD EXTENSION IF NEEDED ---
if ! php -m | grep -q gd; then
  echo "Installing php${PHP_VERSION}-gd..."
  apt install -y php${PHP_VERSION}-gd
fi

# --- PREVIEW GENERATOR CONFIG ---
sed -i "/);/i 'preview_max_x' => 2048,\n  'preview_max_y' => 2048,\n  'jpeg_quality' => 60," "$CONFIG_FILE"
echo "Preview generator configuration added to $CONFIG_FILE."

# --- INSTALL & ENABLE PREVIEW GENERATOR APP ---
sudo -u www-data php "$OCC" app:install previewgenerator || true
sudo -u www-data php "$OCC" app:enable previewgenerator
echo "Preview Generator app installed and enabled."

# --- GENERATE PREVIEWS ---
sudo -u www-data php "$OCC" preview:generate-all
echo "Previews generated."

# --- RESTART APACHE ---
systemctl restart apache2
echo "Apache restarted."

echo "\nMaintenance setup complete. Backup of config.php is at $CONFIG_FILE.bak.*"
