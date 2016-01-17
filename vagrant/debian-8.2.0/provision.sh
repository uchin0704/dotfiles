#!/usr/bin/env bash
#
# References:
#   https://github.com/fideloper/Vaprobash
#   https://www.linode.com/docs/websites/apache/running-fastcgi-php-fpm-on-debian-7-with-apache
#   https://github.com/w0ng/dotfiles/blob/master/.vimrc

# =============================================================================

echo "--- Changing locale to Australia and timezone to Australia/Sydney ---"

export LANG="en_AU.UTF-8"
sed -ri 's/^([^#].*)/# \1/' /etc/locale.gen
echo "en_AU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

timedatectl set-timezone "Australia/Sydney"

# =============================================================================

echo "--- Adding non-free repository ---"

sed -ri "s/^(deb.* main)$/\1 non-free/" /etc/apt/sources.list

echo "non-free repository added."

# =============================================================================

echo "--- Installing base packages ---"

# Set parameters for unattended grub-pc upgrade
export UCF_FORCE_CONFFNEW=YES
debconf-set-selections <<< 'grub-pc grub-pc/timeout string 0'
sdaid="/dev/$(udevadm info --name=/dev/sda --query=symlink)"
debconf-set-selections <<< "grub-pc grub-pc/install_devices multiselect $sdaid"
unset sdaid

apt-get update
apt-get upgrade -y
apt-get install -y \
    curl \
    git-core \
    python-software-properties \
    unzip

# =============================================================================

# Set mysql root user password to 'vagrant'
debconf-set-selections <<< \
    'mysql-server mysql-server/root_password password vagrant'
debconf-set-selections <<< \
    'mysql-server mysql-server/root_password_again password vagrant'

echo "--- Installing Apache, MySQL and PHP ---"

apt-get install -y \
    apache2 \
    apache2-mpm-worker \
    libapache2-mod-fastcgi \
    mysql-server \
    php5-cli \
    php5-fpm \
    php5-curl \
    php5-gd \
    php5-gmp \
    php5-imagick \
    php5-intl \
    php5-ldap \
    php5-mcrypt \
    php5-memcached \
    php5-mysql

# =============================================================================

echo "--- Configuring PHP ---"

# Add vagrant user to group used for PHP5-FPM
usermod -a -G www-data vagrant

# Display all errors
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" \
    /etc/php5/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" \
    /etc/php5/fpm/php.ini

# Set timezone
sed -i "s/^;\?date.timezone =.*/date.timezone = \"Australia\/Sydney\"/" \
    /etc/php5/fpm/php.ini
sed -i "s/^;\?date.timezone =.*/date.timezone = \"Australia\/Sydney\"/" \
    /etc/php5/cli/php.ini

service php5-fpm restart

echo "PHP configured."

# =============================================================================

echo "--- Configuring MySQL ---"

# Set strict mode
sed -i '/\[mysqld\]/a sql_mode = "STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ENGINE_SUBSTITUTION"' \
    /etc/mysql/my.cnf

# Fix deprecated defaults for MySQL 5.5
sed -i 's/key_buffer[^_]/key_buffer_size/' \
        /etc/mysql/my.cnf
sed -i 's/myisam-recover[^-]/myisam-recover-options/' \
        /etc/mysql/my.cnf


service mysql restart

echo "MySQL configured."

# =============================================================================

echo "--- Configuring Apache ---"

SERVER_NAME="$1"
DOC_ROOT="$2"

[[ ! -d "$DOC_ROOT" ]] && mkdir -p "$DOC_ROOT"

# Create a vhost using arguments supplied by VagrantFile
[[ ! -f "${DOC_ROOT}/${SERVER_NAME}.conf" ]] && \
    cat <<EOF > /etc/apache2/sites-available/${SERVER_NAME}.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName ${SERVER_NAME}
    DocumentRoot ${DOC_ROOT}
    <Directory ${DOC_ROOT}>
        Options +Indexes +FollowSymLinks +MultiViews
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/${SERVER_NAME}-error.log
    LogLevel warn
    CustomLog \${APACHE_LOG_DIR}/${SERVER_NAME}-access.log combined
</VirtualHost>
EOF

# Configure FastCGI mod
sed -i '$d' /etc/apache2/mods-available/fastcgi.conf
cat <<EOF >> /etc/apache2/mods-available/fastcgi.conf
  AddType application/x-httpd-fastphp5 .php
  Action application/x-httpd-fastphp5 /php5-fcgi
  Alias /php5-fcgi /usr/lib/cgi-bin/php5-fcgi
  FastCgiExternalServer /usr/lib/cgi-bin/php5-fcgi -socket /var/run/php5-fpm.sock -pass-header Authorization
  <Directory /usr/lib/cgi-bin>
    Require all granted
  </Directory>
</IfModule>
EOF


# Update Apache settings
echo "ServerName localhost" >> /etc/apache2/apache2.conf
cd /etc/apache2/sites-available/ && a2ensite "${SERVER_NAME}".conf
a2dissite 000-default
a2enmod rewrite actions

systemctl restart apache2

echo "Apache configured."

# =============================================================================

echo "--- Installing Composer ---"

curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

echo "Composer installed."

# =============================================================================

echo "--- FINISHED ---"

echo "View the dev site via http://${SERVER_NAME}"
