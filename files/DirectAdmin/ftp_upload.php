#!/bin/bash

# DirectAdmin download script.
# Modified by realcryptonight.

RCLONE=/usr/bin/rclone
MD5=${ftp_md5}

#######################################################
# SETUP

if [ ! -e "${ftp_local_file}" ]; then
	echo "Cannot find backup file ${ftp_local_file} to upload";

	/bin/ls -la ${ftp_local_path}

	/bin/df -h

	exit 11;
fi

get_md5() {
	MF=$1

	MD5SUM=/usr/bin/md5sum
	if [ ! -x ${MD5SUM} ]; then
		return
	fi

	if [ ! -e ${MF} ]; then
		return
	fi

	FMD5=`$MD5SUM $MF | cut -d\  -f1`

	echo "${FMD5}"
}

#######################################################

RET=0;

#######################################################
# Object Storage via rsync
upload_file_to_object_storage()
{
	if [ ! -e ${RCLONE} ]; then
		echo "";
		echo "*** Backup not uploaded ***";
		echo "Please install rclone by running:";
		echo "";
		echo "sudo -v ; curl https://rclone.org/install.sh | sudo bash";
		echo "";
		exit 10;
	fi
	
	$RCLONE --config "/home/${ftp_password_esc_double_quote}/.config/rclone/rclone.conf" copy $ftp_local_file $ftp_username$ftp_path
	RET=$?
	
	if [ "${RET}" -ne 0 ]; then
		echo "rclone return code: $RET";
	fi
}

#######################################################
# Start

upload_file_to_object_storage

if [ "${RET}" = "0" ] && [ "${MD5}" = "1" ]; then
	
	MD5_FILE=${ftp_local_file}.md5
	M=`get_md5 ${ftp_local_file}`
	if [ "${M}" != "" ]; then
		echo "${M}" > ${MD5_FILE}

		ftp_local_file=${MD5_FILE}
		ftp_remote_file=${ftp_remote_file}.md5
		
		upload_file_to_object_storage
	fi
fi

exit $RET

