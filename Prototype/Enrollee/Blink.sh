#!/bin/bash

LED_PATH=/sys/class/leds/ACT
LOGFILE=/tmp/wpa_dpp.log

blink_led() {
echo none | sudo tee $LED_PATH/trigger > /dev/null

for i in {1..20}; do
	echo 1 | sudo tee $LED_PATH/brightness > /dev/null
	sleep 0.1
	echo 0 | sudo tee $LED_PATH/brightness > /dev/null
	sleep 0.1
done
}

tail -Fn0 $LOGFILE | while read line; do
	echo $line | grep -q "EAPOL authentication completed - result=SUCCESS"	
	if [ $? -eq 0 ]; then
		blink_led
	fi
done