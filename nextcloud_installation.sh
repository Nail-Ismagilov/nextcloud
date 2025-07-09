#!/bin/bash

set -euo pipefail

# --- CONFIGURABLE VARIABLES ---
FQDN="${FQDN:-nextcloud.local}"
COUNTRY="${COUNTRY:-DE}"
STATE="${STATE:-Baden-Wuerttemberg}"
CERT_DIR="/etc/ssl/cloud"
APACHE_CONF="/etc/apache2/sites-available/nextcloud-ssl.conf"
NEXTCLOUD_LOGS="/var/www/nextcloud/logs"
DB_NAME="${DB_NAME:-nextcloud}"
DB_USER="${DB_USER:-nextclouduser}"
DB_PASS="${DB_PASS:-}"
PHP_VERSION="8.3"

# --- ROOT CHECK ---
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo." >&2
  exit 1
fi

# --- PROMPT FOR DB PASSWORD IF NOT SET ---
if [[ -z "$DB_PASS" ]]; then
  read -rsp "Enter password for Nextcloud database user: " DB_PASS
  echo
fi

# --- UPDATE SYSTEM ---
echo "Updating system..."
apt update && apt upgrade -y

# --- INSTALL PACKAGES ---
echo "Installing required packages..."
apt install -y apache2 mariadb-server unzip openssl curl apt-transport-https ffmpeg redis-server \
  libmagickcore-6.q16-6-extra php php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-intl php${PHP_VERSION}-curl php${PHP_VERSION}-mbstring \
  php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-ldap php${PHP_VERSION}-gd php${PHP_VERSION}-bz2 php${PHP_VERSION}-sqlite3 php${PHP_VERSION}-redis php${PHP_VERSION}-bcmath php${PHP_VERSION}-gmp php${PHP_VERSION}-imagick jq

# --- ADD PHP REPO IF NEEDED ---
if ! grep -q 'packages.sury.org' /etc/apt/sources.list.d/php.list 2>/dev/null; then
  echo "Adding PHP repository..."
  curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
  echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
  apt update
fi

# --- ENABLE APACHE MODULES ---
a2enmod proxy_fcgi setenvif ssl rewrite headers

a2enconf php${PHP_VERSION}-fpm

# --- PHP CONFIGURATION ---
echo "Configuring PHP..."
sed -i 's/memory_limit = .*/memory_limit = 1G/' /etc/php/${PHP_VERSION}/fpm/php.ini
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 10G/' /etc/php/${PHP_VERSION}/fpm/php.ini
sed -i 's/max_file_uploads = .*/max_file_uploads = 50/' /etc/php/${PHP_VERSION}/fpm/php.ini
sed -i 's/;opcache.interned_strings_buffer = .*/opcache.interned_strings_buffer = 32/' /etc/php/${PHP_VERSION}/fpm/php.ini

systemctl restart php${PHP_VERSION}-fpm
systemctl restart apache2

echo "PHP configuration updated."

# --- INSTALL TAILSCALE ---
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable --now tailscaled

echo "Tailscale installed. To connect this machine to your Tailscale network, run:"
echo "  sudo tailscale up"
echo "and follow the authentication instructions in your browser."
echo "For more information, see: https://tailscale.com/kb/"

echo "Waiting for Tailscale connection..."
while ! tailscale status --json 2>/dev/null | jq -e '.Self.DNSName' >/dev/null; do
  sleep 2
done
MAGICDNS_NAME=$(tailscale status --json | jq -r '.Self.DNSName')
echo "Tailscale MagicDNS name detected: $MAGICDNS_NAME"

# --- SECURE MARIADB ---
echo "Securing MariaDB..."
mysql -u root <<EOF
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF

# --- CREATE NEXTCLOUD DB AND USER ---
echo "Creating Nextcloud database and user..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "Database and user created."

# --- DOWNLOAD AND INSTALL NEXTCLOUD ---
echo "Downloading Nextcloud..."
wget -q https://download.nextcloud.com/server/releases/latest.zip -O /tmp/nextcloud.zip
unzip -q /tmp/nextcloud.zip -d /tmp/
mv /tmp/nextcloud /var/www/
chown -R www-data:www-data /var/www/nextcloud/
chmod -R 755 /var/www/nextcloud/
mkdir -p "$NEXTCLOUD_LOGS"
rm -f /tmp/nextcloud.zip

echo "Nextcloud files installed."

# --- SSL CERTIFICATE ---
echo "Generating self-signed SSL certificate for $FQDN and $MAGICDNS_NAME..."
mkdir -p "$CERT_DIR"
openssl req -x509 -nodes -days 36500 -newkey rsa:2048 \
  -keyout "$CERT_DIR/cloud.key" \
  -out "$CERT_DIR/cloud.crt" \
  -subj "/C=$COUNTRY/ST=$STATE/L=/O=/OU=/CN=$FQDN" \
  -addext "subjectAltName=DNS:$FQDN,DNS:$MAGICDNS_NAME"

echo "SSL certificate created."

# --- APACHE CONFIGURATION ---
echo "Configuring Apache for Nextcloud..."
cat > "$APACHE_CONF" <<EOF
<VirtualHost *:80>
    ServerName $FQDN
    ServerAlias $MAGICDNS_NAME
    Redirect permanent / https://$FQDN/
</VirtualHost>

<VirtualHost *:443>
    ServerAdmin admin@$FQDN
    ServerName $FQDN
    ServerAlias $MAGICDNS_NAME
    DocumentRoot /var/www/nextcloud
    SSLEngine on
    SSLCertificateFile $CERT_DIR/cloud.crt
    SSLCertificateKeyFile $CERT_DIR/cloud.key
    <Directory /var/www/nextcloud/>
        Options +FollowSymlinks
        AllowOverride All
        <IfModule mod_dav.c>
            Dav off
        </IfModule>
        <IfModule mod_headers.c>
            Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains"
        </IfModule>
        SetEnv HOME /var/www/nextcloud
        SetEnv HTTP_HOME /var/www/nextcloud
        Satisfy Any
    </Directory>
    ErrorLog $NEXTCLOUD_LOGS/error.log
    CustomLog $NEXTCLOUD_LOGS/access.log combined
</VirtualHost>
EOF

a2dissite 000-default.conf || true
a2ensite nextcloud-ssl.conf
systemctl reload apache2

echo "Apache configured for Nextcloud."

echo "\n--- INSTALLATION COMPLETE ---"
echo "1. Add your server IP and FQDN to /etc/hosts if needed (e.g. 10.0.0.1 $FQDN)"
echo "2. Open https://$FQDN/ or https://$MAGICDNS_NAME/ in your browser to complete Nextcloud setup."
echo "3. Database: $DB_NAME, User: $DB_USER, Password: (what you entered)"
echo "4. Tailscale: Run 'sudo tailscale up' to connect this machine to your Tailscale network if not already connected."
echo "\nFor more details, see the README.md."
