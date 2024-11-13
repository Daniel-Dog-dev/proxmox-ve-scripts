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

pvelicense="none"
storagelocation="auto"
pvesshkeysurl=""

infoBanner()
{
   echo "Copyright (c) 2023 realcryptonight"
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

while getopts "l:s:k:hv" opt; do
  case ${opt} in
	h)
		infoBanner
		echo "Syntax: install.sh [-l|-s|-h|-v]"
   		echo "options:"
		echo "-l (required)	Specify the Proxmox VE license key (Default: none)"
		echo "-s (optional)	Specify the VM disk location. (Default: auto detect)"
		echo "-k (optional)	Specify a URL to get the authorized_keys file from for user \"root\""
		echo "-h		Print this help page."
   		echo "-v		Print the script version."
		exit 0
	  ;;
	l)
		pvelicense="${OPTARG}"
	  ;;
	s)
	  	storagelocation="${OPTARG}"
	  ;;
	k)
		pvesshkeyurl="${OPTARG}"
	  ;;
	v)
		infoBanner
		echo "Version: 1.0"
	  	exit 0
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
        pvesubscription set $pvelicense
        pvesubscription update -force
        retries=0
        while [[ ! $(pvesubscription get) =~ "status: active" ]]; do
                if [ $retries -gt 5 ]; then
                        echo "Failed to active lincense. Please check your license key."
                        exit 1
                fi

                let "retries++"
                echo "License is not (yet) active. Waiting 10 seconds..."
                sleep 10s
        done
fi

if [ "$storagelocation" == "auto" ];
then
	echo "For storage auto-detect is used."
	if [ "$(pvesm scan lvm)" != "" ]; then
		echo "auto-detect detected that a LVM is used."
        	storagelocation="local-lvm"
	else
		echo "auto-detect detected that no LVM is used. Assuming ZFS."
        	storagelocation="local-zfs"
	fi
fi

apt update
apt -y dist-upgrade
apt install -y figlet vim dnsmasq

rm /etc/motd
mv ./files/00-header /etc/update-motd.d/
mv ./files/10-sysinfo /etc/update-motd.d/
mv ./files/10-uname /etc/update-motd.d/
mv ./files/90-footer /etc/update-motd.d/
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

mv ./snippets/standard.yaml /var/lib/vz/snippets/standard.yaml
mv ./snippets/directadmin.yaml /var/lib/vz/snippets/directadmin.yaml

mkdir /custom-scripts/
mv ./custom-scripts/create_templates.sh /custom-scripts/create_templates.sh
mv ./custom-scripts/backup_upload.sh /custom-scripts/backup_upload.sh
chmod 755 /custom-scripts/create_templates.sh
chmod 755 /custom-scripts/backup_upload.sh

/custom-scripts/create_templates.sh -s "$storagelocation"
echo "0 5    * * *   root    /custom-scripts/create_templates.sh -q -s \"$storagelocation\"" >> /etc/crontab

if [ "$pvesshkeysurl" != "" ];
then
	echo "URL for user \"root\" authorized_keys file is given."
	
	mv /root/.ssh/authorized_keys /root/.ssh/authorized_keys.old

	echo "Downloading authorized_keys file..."
	wget -q $pvesshkeysurl -O /root/.ssh/authorized_keys
	echo "Downloaded authorized_keys file."
	chmod 600 /root/.ssh/authorized_keys
fi
