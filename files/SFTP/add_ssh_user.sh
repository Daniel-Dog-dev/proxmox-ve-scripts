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
adduser --home /backups/$1 $1

# Add the user to the sftpgroup group.
usermod -G sftpgroup $1

# Make the user and sftpgroup owner of the home directory.
chown $1:sftpgroup /backups/$1/

# Make the home directory only accessible by the user.
chmod 700 /backups/$1/

# Add the .ssh directory to the user home directory.
mkdir /backups/$1/.ssh

# Make the user the only owner of the .ssh directory.
chown $1:$1 /backups/$1/.ssh/

# Make the .ssh directory only accessible by the user.
chmod 700 /backups/$1/.ssh/