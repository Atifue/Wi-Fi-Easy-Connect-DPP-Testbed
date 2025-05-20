#!/bin/bash

CONFIG_FILE=/etc/dpp/dpp.conf

sudo echo -e "ctrl_interface=DIR=/var/run/wpa_supplicant\nctrl_interface_group=0\nupdate_config=1\npmf=2\ndpp_config_processing=2" > $CONFIG_FILE