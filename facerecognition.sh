#!/bin/bash

# Update package list
sudo apt-get update

# Install dependencies
sudo apt-get install -y libx11-dev libopenblas-dev liblapack-dev cmake php-dev php8.2-dev

# Install PDlib
cd /tmp
git clone https://github.com/davisking/dlib.git
cd dlib/dlib
mkdir build
cd build
cmake -DDLIB_NO_GUI_SUPPORT=OFF ..
make
sudo make install

# Install PHP extension for PDlib
cd /tmp
git clone https://github.com/goodspb/pdlib.git
cd pdlib
phpize
./configure --enable-debug
make
sudo make install

# Add PDlib extension to PHP configuration
echo "[pdlib]" | sudo tee -a /etc/php/8.3/fpm/php.ini
echo "extension=pdlib.so" | sudo tee -a /etc/php/8.3/fpm/php.ini

# Restart PHP-FPM
sudo systemctl restart php8.2-fpm

# Install Face Recognition app in Nextcloud
cd /var/www/nextcloud/apps
sudo -u www-data git clone https://github.com/matiasdelellis/facerecognition.git
sudo -u www-data php /var/www/nextcloud/occ app:enable facerecognition

# Download models for Face Recognition app
sudo -u www-data php /var/www/nextcloud/occ recognize:download-models
sudo -u www-data php /var/www/nextcloud/occ face:setup -M MEMORY # or ./occ face:setup --memory MEMORY
sudo -u www-data php /var/www/nextcloud/occ face:setup -m MODEL_ID # or ./occ face:setup -m MODEL_ID
echo "Face Recognition app installed successfully!"
