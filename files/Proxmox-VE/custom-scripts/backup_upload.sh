#!/bin/bash
#	
#	MIT License
#	
#	Copyright (c) 2024 Daniel-Dog
#	
#	Permission is hereby granted, free of charge, to any person obtaining a copy
#	of this software and associated documentation files (the "Software"), to deal
#	in the Software without restriction, including without limitation the rights
#	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#	copies of the Software, and to permit persons to whom the Software is
#	furnished to do so, subject to the following conditions:
#	
#	The above copyright notice and this permission notice shall be included in all
#	copies or substantial portions of the Software.
#	
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#	SOFTWARE.

rcloneremote=("Proxmox-VE-Backup") # The name of the remote(s) target in the rclone config file. (Please ONLY USE CRYPT REMOTE(S)! If not then backups will be uploaded without encryption)
backupage="7d" # How old backups files should be when they are deleted. (See: https://rclone.org/commands/rclone_delete/ --min-age)
rclonebwlimit="" # Set an max upload speed for the backup upload or leave empty to not configure a upload speed limit. (See: https://rclone.org/docs/#bwlimit-bandwidth-spec)

if [ $1 != "backup-end" ] && [ $1 != "log-end" ]; then
	exit 0
fi

echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
echo "Custom rclone backup upload script"
echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

if [ ! -f "/usr/bin/rclone" ]; then
	echo "Rclone is not installed!"
	exit 1
fi

if [ ! -f "/root/.config/rclone/rclone.conf" ]; then
	echo "No rclone config configured!"
	echo "Please make sure you have rclone remote(s) configured."
	echo "And make sure the rclone config is at /root/.config/rclone/rclone.conf"
	exit 1
fi

upload_file() {

	if [ -z $rcloneremote ]; then
		echo "No backup remote(s) configured."
		echo "Please configure backup remote(s) in the 'rcloneremote' variable."
		return 1
	fi
	
	if [ -z $1 ]; then
		echo "No backup file location provided."
		echo "Please make sure the path + filename is provided as the first function argument."
		return 1
	fi
	
	if [ -z $2 ]; then
		echo "No VM ID provided."
		echo "Please make sure the VM ID is provided as the second argument."
		return 1
	fi

	code=0

	for remote in "${rcloneremote[@]}"
	do
		echo "Uploading file: $(basename -- "$1")"
		echo "Uploading to: $remote:/$(hostname)/$2/"
		
		if [ -z $rclonebwlimit ]; then
			/usr/bin/rclone --config /root/.config/rclone/rclone.conf copy $1 $remote:/$(hostname)/$2 --progress --stats 30s
			if [ $? -ne 0 ]; then
				code=1
			fi
		else
			/usr/bin/rclone --config /root/.config/rclone/rclone.conf copy $1 $remote:/$(hostname)/$2 --bwlimit $rclonebwlimit --progress --stats 30s
			if [ $? -ne 0 ]; then
				code=1
			fi
		fi
		
	done
	
	return $code
}

remove_old() {
	
	if [ -z $remote ]; then
		echo "No backup remote(s) configured."
		echo "Please configure backup remote(s) in the 'rcloneremote' variable."
		return 1
	fi
	
	if [ -z $backupage ]; then
		echo "No backup deletion age set."
		echo "Skipping backup age deletion."
		return 0
	fi
	
	echo "Removing backup files older then $backupage"
	
	code=0

	for remote in "${rcloneremote[@]}"
	do
		echo "Removing old backup(s) from: $remote:/$(hostname)/"
		
		/usr/bin/rclone --config /root/.config/rclone/rclone.conf delete $remote:/$(hostname)/ --min-age $backupage -v
		if [ $? -ne 0 ]; then
			code=1
		fi
		
	done
	
	return $code
}

if [ $1 == "backup-end" ]; then
	upload_file $TARGET $3

	if [ $? -eq 0 ]; then
		remove_old
		exit $?
	fi
	
	echo "Backup upload was not successfull."
	echo "Backup age deletion is skipped for safety!"
	exit 1
fi

if [ $1 == "log-end" ]; then
	
	upload_file $LOGFILE $3
	
	if [ $? -eq 0 ]; then
		exit 0
	fi
	
	echo "Backup log upload was not successfull!"
	exit 1
fi

exit 254
