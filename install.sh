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

pvelicense=""

storagelocation=""
snippetlocation=""

networkbridge="vmbr0"

vcores=4
memory=16384
balloonmemory=4096

pool=""

infoBanner()
{
   echo "Copyright (c) 2024 Daniel-Dog"
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
		echo "Version: 1.2"
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
	sed -i 's\deb \#deb \g' /etc/apt/sources.list.d/pve-enterprise.list
	sed -i 's\deb \#deb \g' /etc/apt/sources.list.d/ceph.list
	echo "# Proxmox VE pve-no-subscription repository provided by proxmox.com," >> /etc/apt/sources.list.d/pve-no-subscription.list
	echo "# NOT recommended for production use" >> /etc/apt/sources.list.d/pve-no-subscription.list
	echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >> /etc/apt/sources.list.d/pve-no-subscription.list
	echo "# Proxmox VE CEPH pve-no-subscription repository provided by proxmox.com," >> /etc/apt/sources.list.d/ceph-no-subscription.list
	echo "# NOT recommended for production use" >> /etc/apt/sources.list.d/ceph-no-subscription.list
	echo "deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription" >> /etc/apt/sources.list.d/ceph-no-subscription.list
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

apt update
apt -y dist-upgrade
apt install -y figlet vim fail2ban

cp ./files/Proxmox-VE/jail-proxmox.local /etc/fail2ban/jail.local
cp ./files/Proxmox-VE/proxmox.conf /etc/fail2ban/filter.d/proxmox.conf
systemctl restart fail2ban

rm /etc/motd
mv ./files/Standard/00-header /etc/update-motd.d/
mv ./files/Standard/10-sysinfo /etc/update-motd.d/
mv ./files/Standard/10-uname /etc/update-motd.d/
mv ./files/Standard/90-footer /etc/update-motd.d/
chmod 777 /etc/update-motd.d/*

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

mv ./files/Proxmox-VE/snippets/standard.yaml /var/lib/vz/snippets/standard.yaml
mv ./files/Proxmox-VE/snippets/directadmin.yaml /var/lib/vz/snippets/directadmin.yaml

mkdir /custom-scripts/
mv ./files/Proxmox-VE/custom-scripts/create_templates.sh /custom-scripts/create_templates.sh
mv ./files/Proxmox-VE/custom-scripts/backup_upload.sh /custom-scripts/backup_upload.sh
chmod 755 /custom-scripts/create_templates.sh
chmod 755 /custom-scripts/backup_upload.sh

/custom-scripts/create_templates.sh --vcores "$vcores" --memory "$memory" --balloon "$balloonmemory" --network-bridge "$networkbridge" --vm-disk-location "$storagelocation" --snippets-location "$snippetlocation" --pool "$pool"
echo "0 5    * * *   root    /custom-scripts/create_templates.sh --vcores \"$vcores\" --memory \"$memory\" --balloon \"$balloonmemory\" --network-bridge \"$networkbridge\" --vm-disk-location \"$storagelocation\" --snippets-location \"$snippetlocation\" --pool \"$pool\" -quiet" >> /etc/crontab
