#!/bin/bash
#	
#	MIT License
#	
#	Copyright (c) 2024 Daniel-Doggy
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

if [ "$(id -u)" != 0 ]; then
	 echo "This script requires root privileges."
	 exit 1
fi

scriptpath=$(dirname "$(realpath -s "$0")")

forceupdate=false
verbose=true

storagelocation=""
snippetlocation=""

networkbridge="vmbr0"

vcores=4
memory=16384
balloonmemory=4096

pool=""

createTemplate() {
	pvesh get /cluster/resources --type vm --output-format yaml | grep -E -i 'vmid' > "$scriptpath"/cache/vmidcheck.txt

	if grep -q "vmid: $1" "$scriptpath/cache/vmidcheck.txt" ; then
		if $forceupdate ; then
			if $verbose ; then
				echo "Force update is set. Removing VM ID $1..."
			fi

			qm destroy "$1" -purge
			rm "$scriptpath"/cache/vmidcheck.txt
		else
			if $verbose ; then
				echo "VMID $1 already exists. Skipping..."
			fi

			rm "$scriptpath"/cache/vmidcheck.txt
			return
		fi
	fi

	qm create "$1" --name "$3" --ostype l26
	qm set "$1" --net0 virtio,bridge="$networkbridge"
	qm set "$1" --serial0 socket --vga serial0
	qm set "$1" --memory "$memory" --cores "$vcores" --cpu host
	qm set "$1" --balloon "$balloonmemory"
	qm set "$1" --scsi0 "$storagelocation":0,import-from="$scriptpath/cache/debian-$2-genericcloud-amd64.qcow2",discard=on,ssd=1
	qm set "$1" --boot order=scsi0 --scsihw virtio-scsi-single
	qm set "$1" --onboot 1
	qm set "$1" --agent enabled=1,fstrim_cloned_disks=1
	qm set "$1" --ide2 "$storagelocation":cloudinit
	qm set "$1" --ipconfig0 ip=dhcp,ip6=dhcp
	qm set "$1" --cicustom "user=$snippetlocation:snippets/$4"
	qm disk resize "$1" scsi0 50G
	qm template "$1"
	if [ -n "$pool" ];
	then
		pvesh set /pools/"$pool" -vms "$1"
	fi
}

cacheDebianFiles(){
        if [ ! -d "$scriptpath/cache" ]; then
                if $verbose ; then
                        echo "No cache directory found. Creating cache directory."
                fi

                mkdir "$scriptpath"/cache/

                if $verbose ; then
                        echo "Created cache directory."
                fi
        fi

        if [ -f "$scriptpath/cache/debian-$1-genericcloud-amd64.qcow2" ]; then
                if $verbose ; then
                        echo "Debian $1 image found in cache directory."
                        echo "Checking if cached Debian $1 is still the latest version..."
                fi

                wget -q https://cloud.debian.org/images/cloud/$1/latest/SHA512SUMS -O "$scriptpath"/cache/Debian-$1-SHA512-sums.txt

                if ! grep -Fxq "$(sha512sum "$scriptpath"/cache/debian-$1-genericcloud-amd64.qcow2 | awk '{print $1}')  debian-$1-genericcloud-amd64.qcow2" "$scriptpath"/cache/Debian-$1-SHA512-sums.txt
                then
                        if $verbose ; then
                                echo "The cached Debian $1 image seems to be old. Removing old cached Debian $1 image."
                        fi

                        rm "$scriptpath"/cache/debian-12-genericcloud-amd64.qcow2

                        if $verbose ; then
                                echo "Removed old cached Debian $1 image."
                        fi
                else
                        if $verbose ; then
                                echo "The cached Debian $1 image seems to be up-to-date. Skipping new image download."
                        fi
                fi

                if [ -f "$scriptpath/cache/Debian-$1-SHA512-sums.txt" ]; then
                        rm "$scriptpath"/cache/Debian-$1-SHA512-sums.txt
                fi
        fi

        if [ ! -f "$scriptpath/cache/debian-$1-genericcloud-amd64.qcow2" ]; then
                if $verbose ; then
                        echo "Downloading lastest Debian $2 $1 image."
                fi

                wget -q "https://cloud.debian.org/images/cloud/$1/latest/debian-$2-genericcloud-amd64.qcow2" -O "$scriptpath"/cache/debian-$1-genericcloud-amd64.qcow2

                if $verbose ; then
                        echo "Downloaded lastest Debian $2 $1 image."
                fi
        fi
}

infoBanner()
{
   echo "Copyright (c) 2024 Daniel-Doggy"
   echo ""
   echo "Permission is hereby granted, free of charge, to any person obtaining a copy"
   echo "of this software and associated documentation files (the \"Software\"), to deal"
   echo "in the Software without restriction, including without limitation the rights"
   echo "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell"
   echo "copies of the Software, and to permit persons to whom the Software is"
   echo "furnished to do so, subject to the following conditions:"
   echo ""
   echo "The above copyright notice and this permission notice shall be included in all"
   echo "copies or substantial portions of the Software."
   echo ""
   echo "THE SOFTWARE IS 2048PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR"
   echo "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,"
   echo "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE"
   echo "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER"
   echo "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,"
   echo "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE"
   echo "SOFTWARE."
   echo
}

while [ $# -gt 0 ]; do
  case $1 in
        --balloon)
                balloonmemory="$2"
          ;;
        --vcores)
                vcores="$2"
          ;;
        --help)
                infoBanner
                echo "Syntax: create_template.sh --[options]"
                echo "options:"
                echo "--vcores                  Specify the vcores assigned to the template VM. (Default: 4)"
                echo "--memory                  Specify the memory amount for the VM. (In MiB) (Default: 16384)"
                echo "--balloon                 Specify the minimum balloon memory. (in MiB) (Default: 4096)"
                echo "--network-bridge          Specify the network bridge name for the VM network card. (Default: vmbr0)"
                echo "--vm-disk-location        Specify the template storage name for the VM disks and Cloud-Init disks. (Required) (Use \"auto\" for auto detect)"
                echo "--snippets-location       Specify the snippets storage name for the Cloud-Init configuration files. (Required)"
                echo "--pool                    Specify the pool name that the VM should be in. (Default: none)"
                echo "--help                    Print this help page."
                echo "--version                 Print the script version."
                echo "--force                   Force template update even if there is no image change."
                echo "--quiet                   Run script quietly."
                exit 0
          ;;
        --memory)
                memory="$2"
          ;;
        --network-bridge)
                networkbridge="$2"
          ;;
        --pool)
                pool="$2"
          ;;
        --version)
                infoBanner
                echo "Version: 1.5"
                exit 0
          ;;
        --vm-disk-location)
                storagelocation="$2"
          ;;
        --snippets-location)
                snippetlocation="$2"
          ;;
        --force)
                forceupdate=true
          ;;
        --quiet)
                verbose=false
          ;;
  esac
  shift
done

if [ -z "$snippetlocation" ]; then
        echo "No Snippets location provided."
        echo "Use: create_templates.sh --snippets-location <location>"
        exit 1
fi

if [ -z "${storagelocation}" ]; then
        echo "No storage location provided."
        echo "Use: create_templates.sh --vm-disk-location <location>"
        exit 1
fi

if [ "$storagelocation" == "auto" ];
then
        if [ "$(pvesm scan zfs)" != "" ]; then
                storagelocation="local-zfs"
        fi

        if [ "$(pvesm scan lvm)" != "" ]; then
                storagelocation="local-lvm"
        fi

        if [ -z "$storagelocation" ]; then
                echo "Failed to detect a storage location."
                echo "Please rerun the create_templates script and specify the storage location."
                echo "create_templates.sh --vm-disk-location <storage location>"
                exit 1
        fi
fi

if [ -f "/var/lock/vm-template-update.lck" ]; then
        echo "Template update script is already running in a different instance. Exiting..."
        exit 1
fi

echo "PID: $$" > /var/lock/vm-template-update.lck

cacheDebianFiles "bookworm" 12
cacheDebianFiles "buster" 10

createTemplate 900 "bookworm" "Debian-bookworm-template" standard.yaml
createTemplate 901 "bookworm" "Debian-bookworm-DirectAdmin-template" directadmin.yaml
createTemplate 902 "bookworm" "Debian-bookworm-Desktop" debian-desktop.yaml
createTemplate 903 "bookworm" "Debian-bookworm-Keycloak" keycloak.yaml

createTemplate 904 "buster" "Debian-buster-template" standard.yaml
createTemplate 905 "buster" "Debian-buster-DirectAdmin-template" directadmin.yaml
createTemplate 906 "buster" "Debian-buster-Desktop" debian-desktop.yaml
createTemplate 907 "buster" "Debian-buster-Keycloak" keycloak.yaml

rm /var/lock/vm-template-update.lck