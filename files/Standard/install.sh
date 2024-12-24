#!/bin/bash

scriptpath=$(dirname "$(realpath -s "$0")")

rm /etc/motd
mv "$scriptpath"/00-header /etc/update-motd.d/
mv "$scriptpath"/10-sysinfo /etc/update-motd.d/
mv "$scriptpath"/10-uname /etc/update-motd.d/
mv "$scriptpath"/90-footer /etc/update-motd.d/
chmod 755 /etc/update-motd.d/*

exit 0
