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

# Check for dependencies
DEPENDENCIES='omxplayer sshpass'
if ! dpkg -s $DEPENDENCIES >/dev/null 2>&1; then

	echo "Installing dependencies ..."

	# Test internet connectivity
	test=google.com
	if ! nc -dzw1 $test 443 > /dev/null 2>&1 && echo |openssl s_client -connect $test:443 2>&1 |awk '
		handshake && $1 == "Verification" { if ($2=="OK") exit; exit 1 }
		$1 $2 == "SSLhandshake" { handshake = 1 }'
	then
		echo "Cannot connect to the internet."
		exit 1
	fi

	# Install dependencies
	apt-get -y install $DEPENDENCIES > /dev/null
	if [[ $? -ne 0 ]]; then
		exit 1
	fi
fi


# Prompt for hostname
PROMPT="Enter hostname"
DEFAULT=camPi
prompt_user
while [[ ! $USERINPUT =~ ^[a-z0-9]{1,62}$; do
	echo "Invalid hostname."
	prompt_user
done
NEWHOSTNAME=$USERINPUT

# Prompt for IP address
PROMPT="Enter IP address"
DEFAULT="10.0.0.1"
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

# disable WiFi
echo "Disabling WiFi ..."
add_line /boot/config.txt "dtoverlay=pi3-disable-wifi"

# disable bluetooth
echo "Disabling bluetooth ..."
add_line /boot/config.txt "dtoverlay=pi3-disable-bt"

# Get current directory, define target directory
BASEDIR=$(cd `dirname $BASH_SOURCE` && pwd)
TARGETDIR="/opt/camPi/bin"
mkdir -p "$TARGETDIR"

# Copy camPi.sh to target directory
cp --no-preserve=owner "$BASEDIR/camPi.sh" "$TARGETDIR"
echo "Copied camPi.sh to $TARGETDIR."

# Create symlink to camPi
ln -sf "$TARGETDIR/camPi.sh" "/usr/local/bin/camPi"
echo "Created symlink /usr/local/bin/camPi → $TARGETDIR/dimPi.sh."

# Copy system.d service
cp --no-preserve=owner $BASEDIR/camPi.service /etc/systemd/system
echo "Copied camPi.service to /etc/systemd/system."

# Enable and start dimPi service
systemctl enable camPi.service
systemctl start camPi.service

echo ""
echo "Done. Please reboot."
