#!/bin/bash

# Variables
FQDN="cloud.local"
COUNTRY="DE"
STATE="Baden-Wuerttemberg"
CERT_DIR="/etc/ssl/cloud"
APACHE_CONF="/etc/apache2/sites-available/nextcloud-ssl.conf"
NEXTCLOUD_LOGS="/var/www/nextcloud/logs"
ZEROTIER_NETWORKID="db64858feda3293e"

# Update system
sudo apt update && sudo apt upgrade -y

# Install necessary packages
sudo apt install -y apache2 mariadb-server  unzip openssl  curl

# Save existing php package list to packages.txt file
sudo dpkg -l | grep php | tee packages.txt

# Add Ondrej's repo source and signing key along with dependencies
sudo apt install -y apt-transport-https
sudo curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
sudo apt update

# Install new PHP 8.3 packages
sudo apt install -y php8.2 php8.2-mysql php8.2-intl php8.2-curl php8.2-mbstring php8.2-xml php8.2-zip php8.2-ldap php8.2-gd php8.2-bz2 php8.2-sqlite3 php8.2-redis
# sudo apt install -y php-mbstring php-xml php-gd php-curl php-zip php-mysql libapache2-mod-php php8.3 php8.3-cli php8.3-{bz2,curl,mbstring,intl}

# Install FPM OR Apache module
sudo apt install php8.2-fpm
# OR
sudo apt install libapache2-mod-php8.2

# On Apache: Enable PHP 8.3 FPM
sudo a2enconf php8.2-fpm


## Download and install zerotier
curl -s https://install.zerotier.com | sudo bash
# Join a ZeroTier network (replace <network_id> with your actual network ID)
sudo zerotier-cli join $ZEROTIER_NETWORKID

# Enable ZeroTier service to start on boot
sudo systemctl enable zerotier-one
sudo systemctl start zerotier-one

## Secure MariaDB
sudo mysql_secure_installation <<EOF

y
n
y
y
y
y
EOF

## Create Nextcloud database and user
sudo mysql -u root <<EOF
CREATE DATABASE nextcloud;
CREATE USER 'nextclouduser'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextclouduser'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# Download and install Nextcloud
wget https://download.nextcloud.com/server/releases/latest.zip
unzip latest.zip
sudo mv nextcloud /var/www/
sudo chown -R www-data:www-data /var/www/nextcloud/
sudo chmod -R 755 /var/www/nextcloud/
sudo mkdir -p $NEXTCLOUD_LOGS

## Create directory for SSL certificate
sudo mkdir -p $CERT_DIR

# Generate self-signed SSL certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout $CERT_DIR/cloud.key \
  -out $CERT_DIR/cloud.crt \
  -subj "/C=$COUNTRY/ST=$STATE/L=/O=/OU=/CN=$FQDN"


# Configure Apache2 for SSL
sudo bash -c "cat > $APACHE_CONF <<EOF
<VirtualHost *:80>
    ServerName mycloud.local
    Redirect permanent / https://mycloud.local/
</VirtualHost>

<VirtualHost *:443>
    ServerAdmin admin@$FQDN
    ServerName $FQDN

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
        #resolve htst warnings
        <IfModule mod_headers.c>
            Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains"
        </IfModule>
        
        SetEnv HOME /var/www/nextcloud
        SetEnv HTTP_HOME /var/www/nextcloud

        Satisfy Any
    </Directory>

    ErrorLog /var/www/nextcloud/logs/error.log
    CustomLog /var/www/nextcloud/logs/access.log combined
</VirtualHost>
EOF"

# Enable SSL and site configuration
sudo a2enmod ssl

sudo a2dissite 000-default.conf
sudo a2ensite nextcloud-ssl.conf
sudo a2enmod rewrite
sudo a2enmod headers
sudo systemctl restart apache2


# # Mount external storage
# sudo mkdir -p /mnt/external_storage
# sudo mount /dev/sda1 /mnt/external_storage

# # Configure fstab for automount
# sudo bash -c 'echo "UUID=<UUID> /mnt/external_storage ext4 defaults 0 2" >> /etc/fstab'

# # Set permissions for external storage
# sudo chown -R www-data:www-data /mnt/external_storage
# sudo chmod -R 755 /mnt/external_storage

# # Print completion message
# echo "Nextcloud installation is complete. External storage is mounted and configured."
# echo "Please complete the Nextcloud setup through the web interface."
# echo "Open your web browser and navigate to http://<your-pi-ip-address> to finish the setup."

######## Additionally needs to be done changes to /etc/hosts file namely add
#ip-address      mycloud.local
# example: 10.147.17.17     mycloud.local
