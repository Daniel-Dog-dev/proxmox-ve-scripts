#!/bin/bash

echo "Triggered" >> /root/triggered.txt
# Get the hostname and domain name for NS records.
serverip=""
retries=0
while [[ $(hostname -I | awk '{print $1}') = "" ]] && [ ! $retries -gt 6 ];; do
		echo "Triggered" >> /root/triggered-$retries.txt
		let "retries++"
		sleep 5s
done

serverip=$(hostname -I | awk '{print $1}')
serverhostname=$(dig -x $serverip +short | sed 's/\.[^.]*$//')
domainhostname=$(echo $serverhostname | sed 's/^[^.]*.//g')
ns1host="ns1.${domainhostname}"
ns2host="ns2.${domainhostname}"

echo "IP: ${serverip}" >> /root/test.txt
echo "domain: ${domainhostname}" >> /root/test.txt