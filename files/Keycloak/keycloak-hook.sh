#!/bin/bash

systemctl stop keycloak

cp $RENEWED_LINEAGE/fullchain.pem /etc/keycloak/conf/server.crt.pem
cp $RENEWED_LINEAGE/privkey.pem /etc/keycloak/conf/server.key.pem
chown keycloak:keycloak /etc/keycloak/conf/server.crt.pem
chown keycloak:keycloak /etc/keycloak/conf/server.key.pem

systemctl start keycloak