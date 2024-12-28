#!/bin/bash

if [ -z "$1" ]
	then
		echo "./add_ssh_user.sh <ssh username>"
		exit
	else
		echo "Username given. Continue."
fi

adduser --disabled-password --gecos "" --home /sftp-backups/$1 $1
mkdir /sftp-backups/$1/.ssh

chown $1:sftpbackup /sftp-backups/$1/
chown $1:$1 /sftp-backups/$1/.ssh/
chmod -R 700 /sftp-backups/$1/

