#!/bin/bash

INTERFACE="wlan1"
LED_PATH=/sys/class/leds/ACT
LOGFILE=/tmp/wpa_dpp.log
CHIP="gpiochip0"
LINE=4

blink_led() {
sleep 5
sudo ip link set $INTERFACE down 2>/dev/null
sudo pkill -f wpa_supplicant 2>/dev/null
sudo pkill -f wpa_supplicant-dpp 2>/dev/null
sudo rm -f /var/run/wpa_supplicant/$INTERFACE 2>/dev/null
sudo /home/irtlab/Desktop/refresh.sh 2>/dev/null
for i in {1..40}
do
	gpioset $CHIP $LINE=1
	sleep 0.1
	gpioset $CHIP $LINE=0
	sleep 0.1
done

}
tail -Fn0 $LOGFILE | while read line; do
	echo $line | grep -q "EAPOL authentication completed - result=SUCCESS"	
	if [ $? -eq 0 ]; then
		blink_led
	fi
done


