#!/bin/bash

# DirectAdmin download script.
# Created by realcryptonight.

RCLONE=/usr/bin/rclone
if [ ! -e ${RCLONE} ]; then
	echo "";
	echo "*** Unable to download file ***";
	echo "Please install rclone by running:";
	echo "";
	echo "sudo -v ; curl https://rclone.org/install.sh | sudo bash";
	echo "";
	exit 10;
fi

TMPDIR="${ftp_local_file//$ftp_remote_file/}"
if [[ ! "$ftp_path" == */ ]]
then
	ftp_path=$ftp_path/
fi

$RCLONE --config "/home/${ftp_password_esc_double_quote}/.config/rclone/rclone.conf" sync $ftp_username$ftp_path$ftp_remote_file $TMPDIR
RET=$?

exit $RET