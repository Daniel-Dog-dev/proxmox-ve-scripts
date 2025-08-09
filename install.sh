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

scriptpath=$(dirname "$(realpath -s "$0")")

pvelicense=""

storagelocation=""
snippetlocation=""

networkbridge="vmbr0"

vcores=4
memory=16384
balloonmemory=4096

pool=""
hpe=""

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
   echo "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR"
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
		echo "Syntax: install.sh [options]"
   		echo "options:"
		echo "--license-key		Specify a Proxmox VE license key (Required) (Use \"none\" for no license key)"
		echo "--vcores			Specify the vcores assigned to the template VM. (Default: 4)"
		echo "--memory			Specify the memory amount for the VM. (In MiB) (Default: 16384)"
		echo "--balloon			Specify the minimum balloon memory. (in MiB) (Default: 4096)"
		echo "--network-bridge		Specify the network bridge name for the VM network card. (Default: vmbr0)"
		echo "--vm-disk-location	Specify the template storage name for the VM disks and Cloud-Init disks. (Required) (Use \"auto\" for auto detect)"
		echo "--snippets-location	Specify the snippets storage name for the Cloud-Init configuration files. (Required)"
		echo "--pool			Specify the pool name that the VM should be in. (Default: none)"
		echo "--help			Print this help page."
		echo "--version			Print the script version."
		echo "--hpe		Add the HPE repository. (Use \"yes\" to add HPE repo)"
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
		echo "Version: 2.0"
	  	exit 0
	  ;;
	--vm-disk-location)
	  	storagelocation="$2"
	  ;;
	--snippets-location)
		snippetlocation="$2"
	  ;;
	--license-key)
		pvelicense="$2"
	  ;;
	--hpe)
		hpe="$2"

  esac
  shift
done

if [ -z "$pvelicense" ]; then
	echo "No Proxmox VE license key provided."
	echo "Use: install.sh --license-key <key>"
	echo "Use \"none\" as key if you do not have a license key."
	exit 1
fi

if [ -z "${storagelocation}" ]; then
	echo "No storage location provided."
	echo "Use: install.sh --vm-disk-location <location>"
	echo "Use \"auto\" for automatic detection."
	exit 1
fi

if [ -z "$snippetlocation" ]; then
	echo "No Snippets location provided."
	echo "Use: install.sh --snippets-location <location>"
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
		echo "Please rerun the install script and specify the storage location."
		echo "install.sh --vm-disk-location <storage location>"
		exit 1
	else
		echo "Detected \"$storagelocation\" as storage location."
	fi
fi

if [ "$pvelicense" == "none" ]; then
	echo "Enabled: false" >> /etc/apt/sources.list.d/pve-enterprise.sources
	echo "Types: deb" >> /etc/apt/sources.list.d/proxmox.sources
	echo "URIs: http://download.proxmox.com/debian/pve" >> /etc/apt/sources.list.d/proxmox.sources
	echo "Suites: trixie" >> /etc/apt/sources.list.d/proxmox.sources
	echo "Components: pve-no-subscription" >> /etc/apt/sources.list.d/proxmox.sources
	echo "Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg" >> /etc/apt/sources.list.d/proxmox.sources

	echo "Enabled: false" >> /etc/apt/sources.list.d/ceph.sources
	echo "" >> /etc/apt/sources.list.d/ceph.sources
	echo "Types: deb" >> /etc/apt/sources.list.d/ceph.sources
	echo "URIs: http://download.proxmox.com/debian/ceph-squid" >> /etc/apt/sources.list.d/ceph.sources
	echo "Suites: trixie" >> /etc/apt/sources.list.d/ceph.sources
	echo "Components: no-subscription" >> /etc/apt/sources.list.d/ceph.sources
	echo "Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg" >> /etc/apt/sources.list.d/ceph.sources

else
	if [[ ! "$pvelicense" =~ \s*pve([1248])([cbsp])-([0-9a-f]){10}\s* ]];
	then
		echo "Proxmox VE license key is invalid!"
		exit 1
	fi
        pvesubscription set $pvelicense
        pvesubscription update -force
        retries=0
        while [[ ! $(pvesubscription get) =~ "status: active" ]]; do
                if [ $retries -gt 5 ]; then
                        echo "Failed to active license. Please check your license key."
                        exit 1
                fi

                let "retries++"
                echo "License is not (yet) active. Waiting 10 seconds..."
                sleep 10s
        done
	echo "Waiting 1 minute for APT to get the authentication data for the Enterprise repository."
	sleep 60s
fi

if [ "$hpe" == "yes" ]; then

	curl -sS https://downloads.linux.hpe.com/SDR/hpPublicKey2048_key1.pub | gpg --dearmor | tee -a /usr/share/keyrings/hpePublicKey.gpg > /dev/null
	curl -sS https://downloads.linux.hpe.com/SDR/hpePublicKey2048_key1.pub | gpg --dearmor | tee -a /usr/share/keyrings/hpePublicKey.gpg > /dev/null
	curl -sS https://downloads.linux.hpe.com/SDR/hpePublicKey2048_key2.pub | gpg --dearmor | tee -a /usr/share/keyrings/hpePublicKey.gpg > /dev/null

	echo "Types: deb" >> /etc/apt/sources.list.d/hpe.sources
	echo "URIs: https://downloads.linux.hpe.com/SDR/repo/mcp" >> /etc/apt/sources.list.d/hpe.sources
	echo "Suites: trixie/current" >> /etc/apt/sources.list.d/hpe.sources
	echo "Components: non-free" >> /etc/apt/sources.list.d/hpe.sources
	echo "Signed-By: /usr/share/keyrings/hpePublicKey.gpg" >> /etc/apt/sources.list.d/hpe.sources
	echo "Enabled: false" >> /etc/apt/sources.list.d/hpe.sources
fi

apt-get update
apt-get -y dist-upgrade
apt-get install -y vim fail2ban sudo

cp "$scriptpath/files/Proxmox-VE/jail-proxmox.local" /etc/fail2ban/jail.local
cp "$scriptpath/files/Proxmox-VE/proxmox.conf" /etc/fail2ban/filter.d/proxmox.conf
systemctl restart fail2ban

sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
service sshd restart

serverhostname=$(dig -x $(hostname -I | awk '{print $1}') +short | sed 's/\.[^.]*$//')
echo "webauthn: rp=$serverhostname,origin=https://$serverhostname:8006,id=$serverhostname" >> /etc/pve/datacenter.cfg

pvesm set local --content snippets,iso,backup,vztmpl
pvesm set $storagelocation --content images,rootdir

while [ ! -d "/var/lib/vz/snippets" ]; do
	echo "No snippets dir yet. Waiting for 5 seconds..."
    sleep 5s
done

mv "$scriptpath/files/Proxmox-VE/snippets/standard.yaml" /var/lib/vz/snippets/standard.yaml
mv "$scriptpath/files/Proxmox-VE/snippets/directadmin.yaml" /var/lib/vz/snippets/directadmin.yaml

mkdir /custom-scripts/
mv "$scriptpath/files/Proxmox-VE/custom-scripts/create_templates.sh" /custom-scripts/create_templates.sh
mv "$scriptpath/files/Proxmox-VE/custom-scripts/backup_upload.sh" /custom-scripts/backup_upload.sh
chmod 755 /custom-scripts/create_templates.sh
chmod 755 /custom-scripts/backup_upload.sh

/custom-scripts/create_templates.sh --vcores "$vcores" --memory "$memory" --balloon "$balloonmemory" --network-bridge "$networkbridge" --vm-disk-location "$storagelocation" --snippets-location "$snippetlocation" --pool "$pool"
echo "0 5    * * *   root    /custom-scripts/create_templates.sh --vcores \"$vcores\" --memory \"$memory\" --balloon \"$balloonmemory\" --network-bridge \"$networkbridge\" --vm-disk-location \"$storagelocation\" --snippets-location \"$snippetlocation\" --pool \"$pool\" --quiet" >> /etc/crontab

if [ -d "/root/.config/rclone" ]; then
	if [ -f "/root/.config/rclone/rclone.conf" ]; then
		apt-get install rclone
		if [ ! -d "/mnt/pve/backups-remote" ]; then
			mkdir /mnt/pve/backups-remote
		fi
		cp "$scriptpath/files/Proxmox-VE/mnt-backups\\x2dremote.mount"
		cp "$scriptpath/files/Proxmox-VE/mnt-backups\\x2dremote.automount"
		systemctl daemon-reload
		systemctl enable "mnt-backups\\x2dremote.automount"
		systemctl start "mnt-backups\\x2dremote.automount"
	fi
fi