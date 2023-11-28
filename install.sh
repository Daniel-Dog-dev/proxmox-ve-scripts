#!/bin/bash

git clone https://github.com/realcryptonight/debian-install-scripts.git
cd debian-install-scripts/
chmod 755 setup-standard.sh
./setup-standard.sh
cd ../

serverhostname=$(dig -x $(hostname -I | awk '{print $1}') +short | sed 's/\.[^.]*$//')
#echo "webauthn: rp=$serverhostname,origin=https://$serverhostname:8006,id=$serverhostname" >> /etc/pve/datacenter.cfg

mv ./snippets/standard.yaml /var/lib/vz/snippets/standard.yaml
mv ./snippets/directadmin.yaml /var/lib/vz/snippets/directadmin.yaml

mkdir /custom-scripts/
mv create_templates.sh /custom-scripts/create_templates.sh
chmod 755 /custom-scripts/create_templates.sh

/custom-scripts/create_templates.sh
echo "0 3    1 * *   root    /custom-scripts/create_templates.sh" >> /etc/crontab