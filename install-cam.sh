#!/bin/bash

# Check for root
if [[ "$EUID" -ne 0 ]]; then
	echo "Please run as root."
	exit 1
fi

# Function for validating IP addresses
function valid_ip() {
	local ip=$1
	local stat=1

	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		OIFS=$IFS
		IFS='.'
		ip=($ip)
		IFS=$OIFS
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
			&& ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
		stat=$?
	fi
	return $stat
}

function add_line() {
	grep -qxF "$2" "$1" || echo "$2" >> "$1"
}

# Function that prompts for user input
function prompt_user() {
	read -e -p "$PROMPT [$DEFAULT]: " USERINPUT
	USERINPUT=${USERINPUT:-"$DEFAULT"}
}

# Prompt for setup ID
PROMPT="Enter setup ID"
DEFAULT="0"
prompt_user
while [[ ! $USERINPUT =~ ^[0-9]{1,2}$ ]]; do
	echo "Invalid setup ID. Use a number from 0 to 99."
	prompt_user
done
ID=$USERINPUT
printf -v ID "%d" $ID

# Prompt for hostname
PROMPT="Enter hostname"
DEFAULT=setup$ID
prompt_user
while [[ ! $USERINPUT =~ ^[a-z0-9-]{1,62}$ || \
	$USERINPUT =~ ^[-] || $USERINPUT =~ [-]$ ]]; do
	echo "Invalid hostname."
	prompt_user
done
NEWHOSTNAME=$USERINPUT

# Prompt for IP address
PROMPT="Enter IP address"
DEFAULT="10.0.0.1$ID"
prompt_user
while ! valid_ip $USERINPUT; do
	echo "Invalid IP address."
	prompt_user
done
IP=$USERINPUT

echo ""
echo "You are about to apply the following changes to this system:"
echo "- set static IP address $IP"
echo "- change hostname from $HOSTNAME to $NEWHOSTNAME"
echo "- enable SSH access"
echo "- enable camera"
echo "- disable camera LED"
echo "- disable WiFi"
echo "- disable bluetooth"
PROMPT="Continue? [y/N] "
read -e -p "$PROMPT" USERINPUT
if [[ ! $USERINPUT =~ ^y$ ]]; then
	echo "Aborting."
	exit 1
fi
echo ""

# set IP address
echo "Setting static IP address ..."
DHCPCD="/etc/dhcpcd.conf"
if ! `grep -q "Written by dimPi" "$DHCPCD"`; then
	cp "$DHCPCD" "$DHCPCD.bak"
fi
echo "# dhcpcd.conf" > "$DHCPCD"
echo "# Written by dimPi" >> "$DHCPCD"
echo "# Original file backed up to $DHCPCD.bak" >> "$DHCPCD"
echo "interface eth0" >> "$DHCPCD"
echo "static ip_address=$IP/24" >> "$DHCPCD"

# set hostname
echo "Updating hostname ..."
sed -i "s/$HOSTNAME/$NEWHOSTNAME/" /etc/hosts
hostnamectl set-hostname $NEWHOSTNAME

# Enable SSH
echo "Enabling SSH ..."
sudo systemctl enable ssh
sudo systemctl start ssh

# enable camera
echo "Enabling camera ..."
raspi-config nonint do_camera 0

# disable camera LED
echo  "Disabling camera LED ..."
add_line /boot/config.txt "disable_camera_led=1"

# disable WiFi
echo "Disabling WiFi ..."
add_line /boot/config.txt "dtoverlay=pi3-disable-wifi"

# disable bluetooth
echo "Disabling bluetooth ..."
add_line /boot/config.txt "dtoverlay=pi3-disable-bt"

echo ""
echo "Done. Please reboot."
