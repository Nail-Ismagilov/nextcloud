#!/bin/bash

set -euo pipefail

# --- ROOT CHECK ---
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo." >&2
  exit 1
fi

# --- CONFIGURATION ---
NEXTCLOUD_PATH="/var/www/nextcloud"
APPS_PATH="$NEXTCLOUD_PATH/apps"
OCC="$NEXTCLOUD_PATH/occ"
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"

# --- CHECKS ---
if [ ! -f "$OCC" ]; then
  echo "Nextcloud occ command not found at $OCC" >&2
  exit 1
fi
if [ ! -d "$APPS_PATH" ]; then
  echo "Nextcloud apps directory not found at $APPS_PATH" >&2
  exit 1
fi
if [ ! -f "$PHP_INI" ]; then
  echo "php.ini not found at $PHP_INI" >&2
  exit 1
fi

# --- UPDATE SYSTEM ---
echo "Updating package list..."
apt-get update

# --- INSTALL DEPENDENCIES ---
echo "Installing dependencies..."
apt-get install -y libx11-dev libopenblas-dev liblapack-dev cmake php-dev php${PHP_VERSION}-dev git

# --- INSTALL PDlib ---
echo "Cloning and building dlib..."
cd /tmp
rm -rf dlib pdlib
if [ ! -d dlib ]; then
  git clone https://github.com/davisking/dlib.git
fi
cd dlib/dlib
mkdir -p build
cd build
cmake -DDLIB_NO_GUI_SUPPORT=OFF ..
make
make install

# --- INSTALL PHP EXTENSION FOR PDlib ---
echo "Cloning and building pdlib..."
cd /tmp
if [ ! -d pdlib ]; then
  git clone https://github.com/goodspb/pdlib.git
fi
cd pdlib
phpize
./configure --enable-debug
make
make install

# --- BACKUP AND EDIT PHP.INI ---
cp "$PHP_INI" "$PHP_INI.bak.$(date +%Y%m%d%H%M%S)"
echo "[pdlib]" >> "$PHP_INI"
echo "extension=pdlib.so" >> "$PHP_INI"
echo "pdlib extension added to $PHP_INI."

# --- RESTART PHP-FPM ---
systemctl restart php${PHP_VERSION}-fpm

echo "PHP-FPM restarted."

# --- INSTALL FACE RECOGNITION APP IN NEXTCLOUD ---
cd "$APPS_PATH"
if [ ! -d facerecognition ]; then
  sudo -u www-data git clone https://github.com/matiasdelellis/facerecognition.git
fi
sudo -u www-data php "$OCC" app:enable facerecognition

echo "Face Recognition app enabled."

# --- DOWNLOAD MODELS FOR FACE RECOGNITION APP ---
sudo -u www-data php "$OCC" recognize:download-models

echo "Models downloaded."

# --- OPTIONAL: SETUP MEMORY/MODEL (USER SHOULD CUSTOMIZE) ---
echo "You may want to run the following commands to complete setup (replace MEMORY and MODEL_ID as needed):"
echo "  sudo -u www-data php $OCC face:setup -M MEMORY"
echo "  sudo -u www-data php $OCC face:setup -m MODEL_ID"

echo "Face Recognition app installed and configured successfully!"

# --- CLEANUP ---
rm -rf /tmp/dlib /tmp/pdlib

echo "Temporary files cleaned up."
