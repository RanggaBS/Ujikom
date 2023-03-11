#!/bin/bash

echo "
----------------------------------
# SCRIPT AUTO INSTALL WEB SERVER #
----------------------------------
"

# Mengecek apakah user login menggunakan user biasa atau user root
if ! [ $(whoami) = "root" ]; then
	echo "Login pake user root dulu masbro.."
	sleep 3
	loginctl terminate-user $(whoami)
	#exit 1
fi

echo "
Mengedit konfigurasi bawaan service di bawah ini:
[-] bind9
	- db.local (/etc/bind/db.local)
	- named.conf.default-zone (/etc/bind/named.conf.default-zone)
[-] apache2
	- 000-default.conf (/etc/apache2/000-default.conf)"
echo -n "\nEdit konfigurasi bawaan? (y/n): "
read EDIT_KONFIGURASI_BAWAAN
EDIT_KONFIGURASI_BAWAAN=$(echo "$EDIT_KONFIGURASI_BAWAAN" | tr '[:upper:]' '[:lower:]')
EDIT_KONFIGURASI_BAWAAN=$( [ "$EDIT_KONFIGURASI_BAWAAN" = "y" ] && echo true || echo false )

# Update repository
echo "\nMengupdate repository.."
if ! [ -e /etc/apt/backup_sources.list ]; then
	cp /etc/apt/sources.list /etc/apt/backup_sources.list;
fi
#sed -i "s/deb/#deb/g" /etc/apt/sources.list
sed -i '/^#/! s/^/# /' /etc/apt/sources.list
echo "
# Repo
deb http://kartolo.sby.datautama.net.id/debian/ buster main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian/ buster-updates main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian-security/ buster/updates main contrib non-free
" >> /etc/apt/sources.list

#sed -i "" /etc/apt/sources.list

# Get IP address
echo "\n\nMendapatkan alamat IP.."
NETWORK_ADAPTER_NAME=$(ip link | awk -F': ' '{print $2}' | grep -v lo)
IP=$(ip -4 addr show $NETWORK_ADAPTER_NAME | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

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
	echo -n "\nMasukkan nama domain: "
	read DNS;
	
	# Get reversed IP address
	#REVERSED_IP=$(echo $IP | awk -F. '{print $4"."$3"."$2"."$1}')	# Full 4 octet
	REVERSED_IP=$(echo $IP | awk -F. '{print $3"."$2"."$1}')	# Only first 3 octet
	IP_LAST_OCTET=$(echo $IP | awk -F. '{print $4}')
	
	if [ $EDIT_KONFIGURASI_BAWAAN = true ]; then
		# DNS forward
		#sed -i '12,14 s/^/;/' /etc/bind/db.local;
		if ! [ -e /etc/bind/db.local_backup ]; then
			cp db.local db.local_backup
		fi
		
		sed -i "13 s/.*/@\tIN\tA\t$IP/" db.local
		sed -i "s/localhost/$DNS/g" db.local
		
		# DNS reverse
		if ! [ -e /etc/bind/db.127_backup ]; then
			cp db.127 db.127_backup
		fi
		sed -i "s/localhost/$DNS/g" db.127
		sed -i "13 s/.*/$IP_LAST_OCTET\tIN\tPTR\t$DNS/" db.127
		
		# DNS zone
		if ! [ -e /etc/bind/db.named.conf.default-zones_backup ]; then
			cp named.conf.default-zones named.conf.default-zones_backup
		fi
		
		sed -i "10 s/.*/zone \"$DNS\" {/" named.conf.default-zones
		sed -i "15 s/.*/zone \"$REVERSED_IP.in-addr.arpa\" {/" named.conf.default-zones
		#sed -i "16 s/.*/\ttype master;/" named.conf.default-zones
		#sed -i "17 s/.*/\tfile \"\/etc\/bind\/db.127\";/" named.conf.default-zones
	else
		# Create backup file
		if ! [ -e /etc/bind/db.dns_forward ]; then
			cp db.local db.dns_forward
		fi
		
		# DNS forward
		sed -i "13 s/.*/@\tIN\tA\t$IP/" db.dns_forward
		sed -i "s/localhost/$DNS/g" db.dns_forward
		
		# DNS reverse
		if ! [ -e /etc/bind/db.dns_reverse ]; then
			cp db.127 db.dns_reverse
		fi
		sed -i "s/localhost/$DNS/g" db.dns_reverse
		sed -i "13 s/.*/$IP_LAST_OCTET\tIN\tPTR\t$DNS/" db.dns_reverse
		
		# DNS zone
		echo -e "\n\n\n\n\n\n" >> named.conf.local
		sed -i "9 s/.*/zone "$DNS" {/" named.conf.local
		sed -i "10 s/.*/\ttype master;/" named.conf.local
		sed -i "11 s/.*/\tfile \"\/etc\/bind\/db.dns_forward\";/" named.conf.local
		sed -i "12 s/.*/};/" named.conf.local
	fi
	
	# Restart bind9 service
	#service bind9 restart
	systemctl restart bind9
	
# Add virtual host
cd /etc/apache2/sites-available/
	cp 000-default.conf $DNS.conf
	sed -i "s/#ServerName www.example.com/ServerName $DNS/g" $DNS.conf
	sed -i "s/ServerAdmin webmaster@localhost/ServerAdmin admin@$DNS/g" $DNS.conf
	sed -i "s/html/wordpress/g" $DNS.conf

# Enable the user's virtual host
#a2ensite $DNS.conf > /dev/null 2>&1
#a2ensite $DNS.conf -q
/sbin/a2ensite $DNS > /dev/null 2>&1

# Disable apache default virtual host
#a2dissite 000-default.conf /dev/null 2>&1
#a2dissite 000-default.conf -q
/sbin/a2dissite 000-default.conf > /dev/null 2>&1

# Prompt user
echo -n "\n\nMasukkan nama database: "
read MySQL_DB_NAME

echo -n "\n\nMasukkan nama user MySQL: "
read MySQL_USER_NAME

echo -n "\n\nMasukkan password user MySQL: "
read MySQL_USER_PASSWORD

echo ''
# Create database & user
mysql -e "CREATE DATABASE IF NOT EXISTS $MySQL_DB_NAME;"
mysql -e "CREATE USER IF NOT EXISTS '$MySQL_USER_NAME'@'localhost' IDENTIFIED BY '$MySQL_USER_PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO '$MySQL_USER_NAME'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

cd /home/
	if ! [ -d /home/Downloads ]; then
		mkdir /home/Downloads
	fi
	cd Downloads/
		if ! [ -e /home/Downloads/wordpress_installer.zip ]; then
			echo "\n\nMendownload file installer WordPress.."
			wget wordpress.org/latest.zip -q --show-progress -O wordpress_installer.zip
		fi

# Extract WordPress installer file
cd /home/Downloads/
	echo "\n\nMengekstrak file installer WordPress.."
	unzip -q -o wordpress_installer.zip
	cd wordpress/
		cp wp-config-sample.php wp-config.php
		echo "\n\nMengatur database WordPress.."
		sed -i "s/database_name_here/$MySQL_DB_NAME/g" wp-config.php
		sed -i "s/username_here/$MySQL_USER_NAME/g" wp-config.php
		sed -i "s/password_here/$MySQL_USER_PASSWORD/g" wp-config.php
		cd ..
	if ! [ -d /var/www/wordpress ]; then
		mkdir /var/www/wordpress
	fi
	cp -r wordpress/* /var/www/wordpress/

# Restart required to apply configuration
#service restart apache2
systemctl restart apache2

echo "
-----------
# SELESAI #
-----------
"
