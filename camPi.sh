#!/bin/bash

# Define IP addresses
IPS[0]=10.0.0.10
IPS[1]=10.0.0.11
IPS[2]=10.0.0.12
IPS[3]=10.0.0.13

# Define labels
LABELS[0]="SETUP 0"
LABELS[1]="SETUP 1"
LABELS[2]="SETUP 2"
LABELS[3]="SETUP 3"

# Define parameters for remote login
REMOTEUSER=pi
REMOTEPASS=raspberry


# DO NOT CHANGE ANYTHING BELOW THIS LINE --------------------------------------


# Get screen resolution
resX=`fbset -s | grep -Po 'mode "\K[^x]*'`
resY=`fbset -s | grep -Po 'mode "[[:digit:]]*x\K[^"]*'`

# Define windows
WIN[0]="0,0,$((resX/2)),$((resY/2))"
WIN[1]="$((resX/2)),0,$resX,$((resY/2))"
WIN[2]="0,$((resY/2)),$((resX/2)),$resY"
WIN[3]="$((resX/2)),$((resY/2)),$resX,$resY"

# Wait for network
echo "Waiting for network ..."
while ! timeout 0.2 ping -c 1 `hostname -I` &> /dev/null; do
	sleep 0.2
done

# Wait for cameras to appear on the network
for i in "${!IPS[@]}"; do
	printf "%s" "Looking for ${IPS[$i]} (${LABELS[$i]}) ..."
	EXIST["$i"]=0
	for j in {1..50}; do
		if timeout 0.2 ping -c 1 -n "${IPS[$i]}" &> /dev/null; then
			echo " Found"
			EXIST["$i"]=1
			break
		else
			printf "%c" "."
		fi
	done
	if [[ "${EXIST[$i]}" -eq 0 ]]; then
		unset "IPS[$i]"
		echo " Not found - giving up"
	fi
done

# Killing existing processes
printf "%s" "Killing existing streams ..."
killall -q screen
for IP in "${IPS[@]}"; do
	sshpass -p$REMOTEPASS ssh $REMOTEUSER@$IP "killall -q -w raspivid" &
done
wait
echo " Done"

# Start streams
PORT=5000
COMMON="raspivid -t 0 -n -ih -sa -100 -w $((resX/2)) -h $((resY/2)) -l -o tcp://0.0.0.0:$PORT"
for i in "${!IPS[@]}"; do
	echo "Starting stream at ${IPS[$i]} (${LABELS[$i]}) ..."
	sshpass -p$REMOTEPASS ssh $REMOTEUSER@${IPS[$i]} "$COMMON -a '${LABELS[$i]}' &>/dev/null" &
done
sleep 0.5

# Watch streams
echo "Connecting to streams ..."
COMMON="--video_fifo 0 --video_queue 0.2"
for i in "${!IPS[@]}"; do
	screen -dmS stream$i sh -c \
		"omxplayer --win ${WIN[$i]} $COMMON tcp://${IPS[$i]}:$PORT" &
done

# Wait for CTRL+C
trap '{ killall -q screen; echo ""; exit 1; }' INT
sleep infinity
