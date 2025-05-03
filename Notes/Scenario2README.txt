Scenario2README

This Scenario is an advanced variant, where the AP is also its Configurator. I am planning to also have Apache2 running on the AP with an API to upload QRCodes from a mobile device. This implementations replaces the need for an Android/IOs implementation of DPP, because the data can be transmitted via a mobile Webbrowser and the AP does the DPP "magic".

In far future this might be advanced with a cloud solution, where APs can pull Bootstrapping Keys of devices, making DPP a usable zero click provisioning tool.

Packages that need to be installed:
xxd, qrencode, python3 (pip: cv2 pyzbar, os), dnsmasq, hostapd, wpa_supplicant, openssl

Work in Progress