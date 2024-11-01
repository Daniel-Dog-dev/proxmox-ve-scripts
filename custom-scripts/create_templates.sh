#!/bin/bash
#	
#	MIT License
#	
#	Copyright (c) 2023 realcryptonight
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

if [ `id -u` != 0 ]; then
	echo "This script requires root privileges."
	exit 1
fi

keepold=0
forceupdate=0
quiet=0

storagelocation="local-zfs"
snippetlocation="local"

createTemplate() {
	
	pvesh get /cluster/resources --type vm --output-format yaml | egrep -i 'vmid' > $(dirname $0)/cache/vmidcheck.txt
	
	if grep -q "vmid: $1" "$(dirname $0)/cache/vmidcheck.txt" ; then
	
		if [ $keepold == 0 ] || [ $forceupdate == 1 ]; then
		
			if [ $quiet == 0 ]; then
				echo "Either keep old templates is not set or force update is set. Removing VM ID $1..."
			fi
			
			qm destroy $1 -purge
			rm $(dirname $0)/cache/vmidcheck.txt
		else
		
			if [ $quiet == 0 ]; then
				echo "VMID $1 already exists. Keep old templates is set and force update is not set. Skipping..."
			fi
			
			rm $(dirname $0)/cache/vmidcheck.txt
			return
		fi
	else
		if [ $quiet == 0 ]; then
			echo "VM ID $1 does not yet exist."
		fi
	fi

	qm create $1 --name $2 --ostype l26
	qm set $1 --net0 virtio,bridge=vmbr0
	qm set $1 --serial0 socket --vga serial0
	qm set $1 --memory 16384 --cores 4 --cpu host
	qm set $1 --scsi0 $storagelocation:0,import-from="$(dirname $0)/cache/debian-12-generic-amd64.qcow2",discard=on,ssd=1
	qm set $1 --boot order=scsi0 --scsihw virtio-scsi-single
	qm set $1 --onboot 1
	qm set $1 --agent enabled=1,fstrim_cloned_disks=1
	qm set $1 --ide2 $storagelocation:cloudinit
	qm set $1 --cicustom "user=$snippetlocation:snippets/$3"
	qm disk resize $1 scsi0 50G
	qm template $1
}

userHelp()
{
   echo "Automaticly create VM templates with the lastest OS versions."
   echo
   echo "Syntax: create_template.sh [-h|-v|-n|-s]"
   echo "options:"
   echo "-h	Print this help page."
   echo "-v	Print the script version."
   echo "-n	Keep the 'old' templates. Only creates templates that do not exist."
   echo "-s	Specify the template storage name for the VM disks and Cloud-Init disks."
   echo "-f	Force template update even if there is no image change. (option -n gets ignored if provided.)"
   echo "-q	Run script quietly."
   echo
}

while getopts "hvns:fq" opt; do
  case ${opt} in
	h)
	  userHelp
	  exit 0
	  ;;
	v)
	  echo "Version: 1.0"
	  exit 0
	  ;;
	n)
	  keepold=1
	  ;;
	s)
	  storagelocation="${OPTARG}"
	  ;;
	f)
	  forceupdate=1
	  ;;
	q)
	  quite=1
	  ;;
    :)
      echo "Option -${OPTARG} requires an argument."
      exit 1
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      exit 1
      ;;
  esac
done

if [ -f "/var/lock/vm-template-update.lck" ]; then
	if [ $quiet == 0 ]; then
		echo "Template update script is already running."
	fi
	exit 1
fi

echo "" > /var/lock/vm-template-update.lck

if [ ! -d "$(dirname $0)/cache" ]; then
	if [ $quiet == 0 ]; then
		echo "No cache directory found. Creating cache directory."
	fi
	mkdir $(dirname $0)/cache/
fi

if [ -f "$(dirname $0)/cache/Debian-Bookworm-SHA512-sums.txt" ]; then
	if [ $quiet == 0 ]; then
		echo "Old Debian Bookworm SHA512 sums found. Removing Debian Bookworm sums file."
	fi
	rm $(dirname $0)/cache/Debian-Bookworm-SHA512-sums.txt
fi

if [ -f "$(dirname $0)/cache/debian-12-generic-amd64.qcow2" ]; then
	if [ $quiet == 0 ]; then
		echo "Debian Bookworm image found in cache directory."
	fi
	wget -q https://cloud.debian.org/images/cloud/bookworm/latest/SHA512SUMS -O $(dirname $0)/cache/Debian-Bookworm-SHA512-sums.txt
	if ! grep -Fxq "$(sha512sum $(dirname $0)/cache/debian-12-generic-amd64.qcow2 | awk '{print $1}')  debian-12-generic-amd64.qcow2" $(dirname $0)/cache/Debian-Bookworm-SHA512-sums.txt
	then
		if [ $quiet == 0 ]; then
			echo "Debian Bookworm image SHA512 sum did not match new Debian Bookworm SHA512 sum. Removing old Debian Bookworm image."
		fi
		rm $(dirname $0)/cache/debian-12-generic-amd64.qcow2
	fi
fi

if [ ! -f "$(dirname $0)/cache/debian-12-generic-amd64.qcow2" ]; then
	if [ $quiet == 0 ]; then
		echo "Downloading lastest Debian Bookworm image."
	fi
	wget -q "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2" -O $(dirname $0)/cache/debian-12-generic-amd64.qcow2
else
	if [ $keepold == 0 ]; then
		if [ $quiet == 0 ]; then
			echo "No new Debian Bookworm image downloaded. Setting keep old to true."
		fi
		keepold=1
	fi
fi

createTemplate 900 "Debian-Bookworm-template" standard.yaml
createTemplate 901 "Debian-Bookworm-DirectAdmin-template" directadmin.yaml

rm /var/lock/vm-template-update.lck
