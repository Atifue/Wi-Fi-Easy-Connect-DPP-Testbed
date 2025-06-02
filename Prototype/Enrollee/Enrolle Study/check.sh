#!/bin/bash


LED_PATH=/sys/class/leds/ACT
LOGFILE=/tmp/wpa_dpp.log
CHIP="gpiochip0"
LINE=4

blink_led() {
for i in {1..5}
do
	gpioset $CHIP $LINE=1
	sleep 0.3
	gpioset $CHIP $LINE=0
	sleep 0.3
done

}
tail -Fn0 $LOGFILE | while read line; do
	echo $line | grep -q "DPP: Remain-on-channel started for listen on 2437 MHz for 5000 ms"	
	if [ $? -eq 0 ]; then
		blink_led
		break
	fi
done


