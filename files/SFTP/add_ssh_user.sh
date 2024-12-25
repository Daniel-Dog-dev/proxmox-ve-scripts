#!/bin/bash

# Check if a username is given.
if [ -z "$1" ]
	then
		echo "./add_ssh_user.sh <ssh username>"
		exit
	else
		echo "Username given. Continue."
fi

# Create a user with the home directory in the /backups folder.
adduser --home /sftp-backups/$1 $1

# Add the user to the sftpgroup group.
usermod -G sftpbackup $1

# Make the user and sftpgroup owner of the home directory.
chown $1:sftpbackup /sftp-backups/$1/

# Make the home directory only accessible by the user.
chmod 700 /sftp-backups/$1/

# Add the .ssh directory to the user home directory.
mkdir /sftp-backups/$1/.ssh

# Make the user the only owner of the .ssh directory.
chown $1:$1 /sftp-backups/$1/.ssh/

# Make the .ssh directory only accessible by the user.
chmod 700 /sftp-backups/$1/.ssh/
