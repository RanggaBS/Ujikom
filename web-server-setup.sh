#!/bin/bash

echo "

----------------------------------
# SCRIPT AUTO INSTALL WEB SERVER #
----------------------------------

"

# Update repository
echo "\nMengupdate repository.."
sed -i "s/deb/#deb/g" /etc/apt/sources.list
echo "
deb http://kartolo.sby.datautama.net.id/debian/ buster main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian/ buster-updates main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian-security/ buster/updates main contrib non-free
" >> /etc/apt/sources.list

# Get IP address
echo "\n\nMendapatkan alamat IP.."
IP=$(ip -4 addr show enp0s3 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
#echo ''

# Do apt commands
echo "\n\nMengupdate paket-paket..\n\n\tSabar masbro.."
apt update > /dev/null 2>&1

#echo "\nUpgrading packages.."
apt upgrade > /dev/null 2>&1

# Install packages
echo "\n\nMenginstall:\n- bind9\n- apache2\n- mariadb-server\n- php\n- php-mysql\n- wget\n- unzip\n\n\tSabar maszeh..\n\tJangan di cancel.\n"
apt install bind9 apache2 mariadb-server php php-mysql wget unzip -y > /dev/null 2>&1

# Configure DNS
cd /etc/bind/
	echo "\nMasukkan nama DNS: "
	read DNS;

	cp db.local db.dns_maju

	echo "
;
; BIND data file for local loopback interface
;
\$TTL    604800
@       IN      SOA     localhost. root.localhost. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@	IN	NS	$DNS.
@	IN	A	$IP
" > db.dns_maju

	echo "
//
// Do any local configuration here
//

// Consider adding the 1918 zones here, if they are not used in your
// organization
//include \"/etc/bind/zones.rfc1918\";

zone \"$DNS\" {
	type master;
	file \"/etc/bind/db.dns_maju\";
};
	" > named.conf.local

	#sed -i "s/-e//g" named.conf.local

	service bind9 restart

# Add virtual host
cd /etc/apache2/sites-available/
	cp 000-default.conf $DNS.conf
	sed -i "s/#ServerName www.example.com/ServerName $DNS/g" $DNS.conf
	sed -i "s/ServerAdmin webmaster@localhost/ServerAdmin admin@$DNS/g" $DNS.conf
	sed -i "s/html/wordpress/g" $DNS.conf

# Enable the user's virtual host
a2ensite $DNS.conf

# Disable apache default virtual host
a2dissite 000-default.conf

# Create MySQL database
echo "\n\nMasukkan nama database: "
read MySQL_DB_NAME

echo "\n\nMasukkan nama user MySQL: "
read MySQL_USER_NAME

echo "\n\nMasukkan password user MySQL: "
read MySQL_USER_PASSWORD

echo ''
# Execute commands
mysql -e "CREATE DATABASE $MySQL_DB_NAME;"
mysql -e "CREATE USER '$MySQL_USER_NAME'@'localhost' IDENTIFIED BY '$MySQL_USER_PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO '$MySQL_USER_NAME'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Download WordPress file installer in the background
cd /home/
	if ! [ -d /home/Downloads ]; then
		mkdir /home/Downloads
	fi
	cd Downloads/
		echo "\n\nMendownload file installer WordPress.."
		wget wordpress.org/latest.zip -q --show-progress -O wordpress_installer.zip
		#echo -e "Started downloading WordPress installer in the background\n\n"

# Extract WordPress installer file
cd /home/Downloads/
	echo "\n\nMengekstrak file installer WordPress.."
	unzip -q -o wordpress_installer.zip
	cd wordpress/
		cp wp-config-sample.php wp-config.php
		sed -i "s/database_name_here/$MySQL_DB_NAME/g" wp-config.php
		sed -i "s/username_here/$MySQL_USER_NAME/g" wp-config.php
		sed -i "s/password_here/$MySQL_USER_PASSWORD/g" wp-config.php
		cd ..
	if ! [ -d /var/www/wordpress ]; then
		mkdir /var/www/wordpress
	fi
	cp -r -f wordpress/* /var/www/wordpress/

# Restart required to apply configuration
service apache2 restart

echo "
-----------
# SELESAI #
-----------
"
