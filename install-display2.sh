#!/bin/bash

# IP addresses of cameras
IPS=(
	10.0.0.10
	10.0.0.11
	10.0.0.12
	10.0.0.13
)

# generate new SSH key
KEYFILE=~/.ssh/id_rsa
if ! test -f "$KEYFILE"; then
	ssh-keygen -f "$KEYFILE" -N ""
fi

# add to known_hosts
for IP in "${IPS[@]}"; do
	if ! ssh-keygen -F $IP &>/dev/null; then
		echo "Adding $IP to ~/.ssh/known_hosts ..."
		{ ssh-keyscan -t ecdsa $IP >> ~/.ssh/known_hosts; } &>/dev/null
	fi
done

# distribute SSH key
REMOTEUSER=pi
REMOTEPASS=raspberry
for IP in "${IPS[@]}"; do
	echo "Distributing SSH key to $IP ..."
	{ sshpass -p $REMOTEPASS ssh-copy-id -i "$KEYFILE" $REMOTEUSER@$IP; } &>/dev/null
done
