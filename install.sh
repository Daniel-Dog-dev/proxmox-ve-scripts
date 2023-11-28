#!/bin/bash

serverhostname=$(dig -x $(hostname -I | awk '{print $1}') +short | sed 's/\.[^.]*$//')

echo "webauthn: rp=$serverhostname,origin=https://$serverhostname:8006,id=$serverhostname"