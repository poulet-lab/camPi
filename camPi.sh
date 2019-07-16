#!/bin/bash

# Define IP addresses
IP1=10.0.0.10
IP2=10.0.0.11
IP3=10.0.0.12
IP4=10.0.0.13

# Define Port
PORT=5000

# Define labels
LABEL1="SETUP 0"
LABEL2="SETUP 1"
LABEL3="SETUP 2"
LABEL4="SETUP 3"



# DO NOT CHANGE ANYTHING BELOW THIS LINE! ==========================

# Get screen resolution
resX=`fbset -s | grep -Po 'mode "\K[^x]*'`
resY=`fbset -s | grep -Po 'mode "[[:digit:]]*x\K[^"]*'`

# Start cameras
COMMON="killall -q -w raspivid; raspivid -t 0 -n -ih -w $((resX/2)) -h $((resY/2)) -l -o tcp://0.0.0.0:$PORT"
ssh pi@$IP1 "$COMMON -a '$LABEL1'" &
ssh pi@$IP2 "$COMMON -a '$LABEL2'" &
ssh pi@$IP3 "$COMMON -a '$LABEL3'" &
ssh pi@$IP4 "$COMMON -a '$LABEL4'" &
sleep 5

# Define windows
WIN1="0,0,$((resX/2)),$((resY/2))"
WIN2="$((resX/2)),0,$resX,$((resY/2))"
WIN3="0,$((resY/2)),$((resX/2)),$resY"
WIN4="$((resX/2)),$((resY/2)),$resX,$resY"

# Start streams
COMMON="--video_fifo 0 --video_queue 0.2"
screen -dmS stream1 sh -c "omxplayer --win $WIN1 $COMMON tcp://$IP1:$PORT"
screen -dmS stream2 sh -c "omxplayer --win $WIN2 $COMMON tcp://$IP2:$PORT"
screen -dmS stream3 sh -c "omxplayer --win $WIN3 $COMMON tcp://$IP3:$PORT"
screen -dmS stream4 sh -c "omxplayer --win $WIN4 $COMMON tcp://$IP4:$PORT"

# Wait for CTRL+C
trap '{ killall -q screen; echo ""; exit 1; }' INT
sleep infinity
