#!/bin/bash

# Log file path
LOGPATH="/var/log/package_install.log"

# Function to log messages
info_msg() {
    echo "$1" | tee -a "$LOGPATH"
}

# Update package list and log
sudo apt update >> "$LOGPATH" 2>&1

# List of required packages
packages=(apache2 mysql-server php php-mysql php-xml php-mbstring php-intl php-json wget certbot python3-certbot-apache)

# Function to check if a package is installed
is_installed() {
    dpkg -l | grep -qw "$1"
}

# Display and log the info message before installation
info_msg "[1/10] Installing required system packages... (This may take several minutes)"

# Install packages
for package in "${packages[@]}"; do
    if is_installed "$package"; then
        info_msg "$package is already installed."
    else
        info_msg "Installing $package..."
        sudo apt install -y "$package" >> "$LOGPATH" 2>&1
    fi
done

# Prompt for the domain name
read -p "Enter your domain name (e.g., help3.igt.com.hk): " DOMAIN

# Download MediaWiki
info_msg "[2/10] Downloading MediaWiki..."
cd /var/www/
sudo wget https://releases.wikimedia.org/mediawiki/1.42/mediawiki-1.42.1.tar.gz

# Extract and configure MediaWiki
info_msg "[3/10] Extracting MediaWiki..."s
sudo tar -xvzf mediawiki-1.42.1.tar.gz
sudo mv mediawiki-1.42.1 mediawiki5

# Set up the database
info_msg "[4/10] Setting up the database..."
sudo mysql -u root -p << EOF
CREATE DATABASE mediawiki5;
CREATE USER 'wikiuser5'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON mediawiki5.* TO 'wikiuser5'@'localhost';
FLUSH PRIVILEGES;
EOF

# Configure Apache
info_msg "[5/10] Configuring Apache..."
sudo bash -c "cat <<EOL > /etc/apache2/sites-available/mediawiki5.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot /var/www/mediawiki5

    <Directory /var/www/mediawiki5>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN_error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN_access.log combined
</VirtualHost>
EOL"

# Enable the site and rewrite module
info_msg "[6/10] Enabling site and rewrite module..."
sudo a2ensite "mediawiki5.conf"
sudo a2enmod rewrite

# Set permissions
info_msg "[7/10] Setting permissions..."
sudo chown -R www-data:www-data /var/www/mediawiki5
sudo chmod -R 755 /var/www/mediawiki5

# Restart Apache
info_msg "[8/10] Restarting Apache..."
sudo systemctl restart apache2

# Obtain SSL certificate
info_msg "[9/10] Obtaining SSL certificate..."
sudo certbot --apache -d "$DOMAIN"

# Delete the MediaWiki tar.gz file
info_msg "[10/10] Cleaning up..."
sudo rm /var/www/mediawiki-1.42.1.tar.gz

info_msg "MediaWiki setup is complete. Please visit https://$DOMAIN to complete the installation."