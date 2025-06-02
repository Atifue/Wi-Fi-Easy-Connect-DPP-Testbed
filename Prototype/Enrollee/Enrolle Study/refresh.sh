#!/bin/bash

CONFIG_FILE=/etc/dpp/dpp.conf

sudo echo -e "ctrl_interface=DIR=/var/run/wpa_supplicant\nctrl_interface_group=0\nupdate_config=1\npmf=2\ndpp_config_processing=2\np2p_listen_reg_class=81\np2p_listen_channel=6" > $CONFIG_FILE
#p2p settings fix issues with wpa_supplicant randomly choosing channels therefore exiting dpp_listening mode