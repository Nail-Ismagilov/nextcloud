# nextcloud
Scripts to install and setup nextcloud on Raspberry Pi

## Prerequisites

- Raspberry Pi running Raspberry Pi OS (or compatible Debian-based OS)
- Internet connection
- Sudo privileges
- (Recommended) System updated via `sudo apt update && sudo apt upgrade -y`
- For Face Recognition: Sufficient storage and memory for compiling dependencies

## Contents

- `nextcloud_installation.sh`: Automated script to install Nextcloud, configure Apache, MariaDB, PHP 8.3, SSL, and Tailscale on a Raspberry Pi. Automatically configures SSL for both your chosen FQDN and the Tailscale MagicDNS name.
- `maintenence_setup.sh`: Script to configure maintenance settings, optimize the database, set up Redis, and enable preview generation in Nextcloud.
- `facerecognition.sh`: Installs dependencies and the Face Recognition app for Nextcloud, including PDlib and required models.
- `wps.sh`: Robust script to connect your Raspberry Pi to Wi-Fi using WPS, with root check, interface selection, error handling, and clear feedback.

## Usage

**1. nextcloud_installation.sh**

This script installs and configures Nextcloud and all required services, using PHP 8.3 and Tailscale for secure remote access.

```bash
chmod +x nextcloud_installation.sh
sudo ./nextcloud_installation.sh
```
- Installs Apache, MariaDB, PHP 8.3, Redis, and other dependencies.
- Sets up SSL with a self-signed certificate for both your chosen FQDN and the Tailscale MagicDNS name.
- Installs and enables Tailscale, waits for connection, and automatically detects the MagicDNS name.
- Configures Apache to serve Nextcloud securely on both FQDN and MagicDNS name.
- Creates the Nextcloud database and user.
- Downloads and sets up Nextcloud in `/var/www/nextcloud`.
- Restarts necessary services.

**Configurable Variables Example:**
You can override default values by setting environment variables before running the script. For example:

```bash
export FQDN=mycloud.example.com
export DB_NAME=cloud_db
export DB_USER=clouduser
export DB_PASS=supersecretpassword
export PHP_VERSION=8.3
sudo -E ./nextcloud_installation.sh
```
- The `-E` flag preserves your environment variables when using sudo.
- You can set any combination of variables: `FQDN`, `DB_NAME`, `DB_USER`, `DB_PASS`, `PHP_VERSION`.

**Tailscale Setup:**
- After installation, you may be prompted to run:
  ```bash
  sudo tailscale up
  ```
  and follow the authentication instructions in your browser.
- The script will automatically detect your Tailscale MagicDNS name and use it for SSL and Apache configuration.
- You can access your Nextcloud instance securely via either:
  - `https://<your-FQDN>/`
  - `https://<your-magicdns-name>.ts.net/`

**2. maintenence_setup.sh**

This script configures maintenance options, database indices, Redis caching, and preview generation.

```bash
chmod +x maintenence_setup.sh
sudo ./maintenence_setup.sh
```
- Adds maintenance window settings to Nextcloud config.
- Adds missing database indices.
- Configures Redis for caching and locking.
- Installs and enables the Preview Generator app.
- Restarts Apache and Redis.

**3. facerecognition.sh**

Installs the Face Recognition app and its dependencies for Nextcloud.

```bash
chmod +x facerecognition.sh
sudo ./facerecognition.sh
```
- Installs system and PHP dependencies.
- Builds and installs PDlib.
- Configures PHP to use PDlib.
- Installs the Face Recognition app in Nextcloud.
- Downloads required models and sets up the app.

**4. wps.sh**

Connects your Raspberry Pi to Wi-Fi using WPS, with robust error handling and interface selection.

```bash
chmod +x wps.sh
sudo ./wps.sh [interface]
```
- `[interface]` is optional (default: wlan0). Example: `sudo ./wps.sh wlan1`
- Checks for root, wpa_cli, wpa_supplicant, and the specified interface.
- Initiates WPS pairing and waits for connection.
- Provides clear feedback on connection status and displays the connected SSID if successful.
- Credentials are saved to `/etc/wpa_supplicant/wpa_supplicant.conf` if the connection is established.
