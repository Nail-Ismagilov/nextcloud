#!/bin/bash

# Define the path to the Nextcloud config.php file
CONFIG_FILE="/var/www/nextcloud/config/config.php"

# Check if the config.php file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "config.php file not found at $CONFIG_FILE"
  exit 1
fi

# Add the maintenance_window_start setting
sudo sed -i "/);/i 'maintenance_window_start' => 1," "$CONFIG_FILE"

echo "Added 'maintenance_window_start' => 1 to $CONFIG_FILE"

# Pfad zur Nextcloud-Installation
NEXTCLOUD_PATH="/var/www/nextcloud"

# Führen Sie den Befehl aus, um fehlende Indizes hinzuzufügen
sudo -u www-data php $NEXTCLOUD_PATH/occ db:add-missing-indices

echo "Fehlende Indizes wurden erfolgreich hinzugefügt!"


# Restart Redis and Apache to apply changes
sudo systemctl restart redis-server


# Define the path to the Nextcloud config.php file
CONFIG_FILE="/var/www/nextcloud/config/config.php"

# Check if the config.php file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "config.php file not found at $CONFIG_FILE"
  exit 1
fi

# Add Redis configuration to config.php
sudo sed -i "/);/i 'memcache.local' => '\\\\OC\\\\Memcache\\\\Redis',\n  'memcache.locking' => '\\\\OC\\\\Memcache\\\\Redis',\n  'redis' => [\n    'host' => 'localhost',\n    'port' => 6379,\n  ]," "$CONFIG_FILE"



# Install necessary PHP extensions
sudo apt install  php-gd -y

# Add preview generator configuration to config.php
sudo sed -i "/);/i 'preview_max_x' => 2048,\n  'preview_max_y' => 2048,\n  'jpeg_quality' => 60," "$CONFIG_FILE"

# Install the Preview Generator app
sudo -u www-data php /var/www/nextcloud/occ app:install previewgenerator

# Enable the Preview Generator app
sudo -u www-data php /var/www/nextcloud/occ app:enable previewgenerator

# Generate previews
sudo -u www-data php /var/www/nextcloud/occ preview:generate-all




sudo systemctl restart apache2
