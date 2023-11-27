#!/bin/bash

wget "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
qm create 900 --name debian-12-template --ostype l26
qm set 900 --net0 virtio,bridge=vmbr0
qm set 900 --serial0 socket --vga serial0
qm set 900 --memory 16384 --cores 4 --cpu host
qm set 900 --scsi0 local:0,import-from="$(pwd)/debian-12-generic-amd64.qcow2",discard=on,ssd=1
qm set 900 --boot order=scsi0 --scsihw virtio-scsi-single
qm set 900 --agent enabled=1,fstrim_cloned_disks=1
qm set 900 --ide2 local:cloudinit
qm set 900 --cicustom "user=local:snippets/standard.yaml"
qm disk resize 900 scsi0 32G
qm template 900