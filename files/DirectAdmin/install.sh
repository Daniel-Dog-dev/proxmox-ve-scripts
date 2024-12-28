#!/bin/bash

installdir=$(dirname "$(realpath -s "$0")")
log_file="${installdir}/install.log"

# Check if the config file exist.
if [ ! -f "${installdir}/config.cnf" ];
then
	echo "Failed to install DirectAdmin." >> $log_file
	echo "config.cnf does not exist." >> $log_file
	exit 1
fi

. "${installdir}/config.cnf"

# Check if the config file contains the DirectAdmin license key.
if [ -z "${directadmin_setup_license_key}" ]
	then
		echo "Failed to install DirectAdmin." >> $log_file
		echo "No DirectAdmin license key was set in the config.cnf file." >> $log_file
		exit 1
fi

# Check if there is a headless email.
if [ -z "${directadmin_setup_headless_email}" ]
	then
		echo "Failed to install DirectAdmin." >> $log_file
		echo "No headless email was set in the config.cnf file." >> $log_file
		exit 1
fi

# Get the hostname and domain name for NS records.
serverip=$(hostname -I | awk '{print $1}')
serverhostname=$(dig -x $serverip +short | sed 's/\.[^.]*$//')
domainhostname=$(echo $serverhostname | sed 's/^[^.]*.//g')
ns1host="ns1.${domainhostname}"
ns2host="ns2.${domainhostname}"

# Set variables to let DirectAdmin install correctly.
if [ -z "${directadmin_setup_admin_username}" ] || [ "${#directadmin_setup_admin_username}" -gt 10 ]
	then
		directadmin_setup_admin_username="admin"
fi
export DA_ADMIN_USER=$directadmin_setup_admin_username
export DA_HOSTNAME=$serverhostname
export DA_NS1=$ns1host
export DA_NS2=$ns2host
export DA_CHANNEL=stable
export DA_FOREGROUND_CUSTOMBUILD=yes
export mysql_inst=mysql
export mysql=8.4
export php1_release=8.4
export php2_release=8.3
export php1_mode=php-fpm

# Download and install DirectAdmin.
wget -O "${installdir}/directadmin.sh" https://download.directadmin.com/setup.sh
chmod 755 "${installdir}/directadmin.sh"
"${installdir}/directadmin.sh" $directadmin_setup_license_key  >> $log_file

# Change some DirectAdmin settings that should be the default.
/usr/local/directadmin/directadmin config-set allow_backup_encryption 1 >> $log_file
/usr/local/directadmin/directadmin config-set backup_ftp_md5 1 >> $log_file

systemctl restart directadmin >> $log_file

/usr/local/directadmin/custombuild/build clean >> $log_file
/usr/local/directadmin/custombuild/build update >> $log_file
/usr/local/directadmin/custombuild/build set_php "imagick" yes >> $log_files
/usr/local/directadmin/custombuild/build composer >> $log_file
/usr/local/directadmin/custombuild/build "php_imagick" >> $log_file

# Check if there is a custom FTP script that needs to be installed.
if [ -f "${installdir}/files/ftp_upload.php" ] && [ -f "${installdir}/files/ftp_download.php" ] && [ -f "${installdir}/files/ftp_list.php" ];
then
	cp "${installdir}/files/ftp_upload.php" /usr/local/directadmin/scripts/custom/
	cp "${installdir}/files/ftp_download.php" /usr/local/directadmin/scripts/custom/
	cp "${installdir}/files/ftp_list.php" /usr/local/directadmin/scripts/custom/
	chmod 700 /usr/local/directadmin/scripts/custom/ftp_upload.php
	chmod 700 /usr/local/directadmin/scripts/custom/ftp_download.php
	chmod 700 /usr/local/directadmin/scripts/custom/ftp_list.php
	chown diradmin:diradmin /usr/local/directadmin/scripts/custom/ftp_upload.php
	chown diradmin:diradmin /usr/local/directadmin/scripts/custom/ftp_download.php
	chown diradmin:diradmin /usr/local/directadmin/scripts/custom/ftp_list.php
	echo "Custom FTP script is installed."  >> $log_file
else
	echo "No Custom FTP script provided. Skipping..."
fi

usermod -aG sudo $directadmin_setup_admin_username

onetimelogin=`/usr/local/directadmin/directadmin login-url --user=$directadmin_setup_admin_username`

echo "{\"hostname\" : \"$serverhostname\", \"login_url\" : \"$onetimelogin\", \"headless_email\" : \"$directadmin_setup_headless_email\"}" > "${installdir}/files/login.json"
/usr/local/bin/php -f "${installdir}/mailer.php"
rm "${installdir}/files/login.json"

exit 0
