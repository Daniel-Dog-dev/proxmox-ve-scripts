#!/bin/bash

if [ "$1" == "auto-remove-old-templates" ]; then

	pvesh get /cluster/resources --type vm --output-format yaml | egrep -i 'vmid' > vmidcheck.txt
	
	if grep -q "vmid: 900" "vmidcheck.txt" ; then
        qm destroy 900 -purge
	fi

	if grep -q "vmid: 901" "vmidcheck.txt" ; then
		qm destroy 901 -purge
	fi
fi

pvesh get /cluster/resources --type vm --output-format yaml | egrep -i 'vmid' > vmidcheck.txt
wget "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"

if ! grep -q "vmid: 900" "vmidcheck.txt" ; then
	qm create 900 --name debian-12-template --ostype l26
	qm set 900 --net0 virtio,bridge=vmbr0
	qm set 900 --serial0 socket --vga serial0
	qm set 900 --memory 16384 --cores 4 --cpu host
	qm set 900 --scsi0 local:0,import-from="$(pwd)/debian-12-generic-amd64.qcow2",discard=on,ssd=1
	qm set 900 --boot order=scsi0 --scsihw virtio-scsi-single
	qm set 900 --agent enabled=1,fstrim_cloned_disks=1
	qm set 900 --ide2 local:cloudinit
	qm set 900 --cicustom "user=local:snippets/standard.yaml"
	qm disk resize 900 scsi0 200G
	qm template 900
fi

if ! grep -q "vmid: 901" "vmidcheck.txt" ; then
	qm create 901 --name directadmin-template --ostype l26
	qm set 901 --net0 virtio,bridge=vmbr0
	qm set 901 --serial0 socket --vga serial0
	qm set 901 --memory 16384 --cores 4 --cpu host
	qm set 901 --scsi0 local:0,import-from="$(pwd)/debian-12-generic-amd64.qcow2",discard=on,ssd=1
	qm set 901 --boot order=scsi0 --scsihw virtio-scsi-single
	qm set 901 --agent enabled=1,fstrim_cloned_disks=1
	qm set 901 --ide2 local:cloudinit
	qm set 901 --cicustom "user=local:snippets/directadmin.yaml"
	qm disk resize 901 scsi0 200G
	qm template 901
fi

rm debian-12-generic-amd64.qcow2