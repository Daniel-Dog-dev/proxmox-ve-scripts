#!/bin/bash

# DirectAdmin download script.
# Modified by realcryptonight.

RCLONE=/usr/bin/rclone
TMPDIR=/home/tmp
RANDNUM=`/usr/local/bin/php -r 'echo rand(0,10000);'`
#we need some level of uniqueness, this is an unlikely fallback.
if [ "$RANDNUM" = "" ]; then
        RANDNUM=$ftp_ip;
fi

DUMP=$TMPDIR/$RANDNUM.dump
rm -f $DUMP
touch $DUMP
chmod 600 $DUMP

#######################################################
# Object Storage via rclone
list_object_storage()
{
	if [ ! -e ${RCLONE} ]; then
		echo "";
		echo "*** Unable to get list ***";
		echo "Please install rclone by running:";
		echo "";
		echo "sudo -v ; curl https://rclone.org/install.sh | sudo bash";
		echo "";
		exit 10;
	fi
	
	$RCLONE --config "/home/${ftp_password_esc_double_quote}/.config/rclone/rclone.conf" lsf --format "p" --files-only $ftp_username$ftp_path
	RET=$?

	if [ "$RET" -ne 0 ]; then
		echo "${RCLONE} returned error code $RET";
		cat $DUMP
	else
		cat $DUMP | grep -v -e '^d'
	fi
}

#######################################################
# Start

list_object_storage

rm -f $DUMP

exit $RET
