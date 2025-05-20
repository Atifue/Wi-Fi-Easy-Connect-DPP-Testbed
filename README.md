# Wi-Fi Easy Connect – DPP Testbed 

This repository documents the setup and testing of a **Wi-Fi Easy Connect (Device Provisioning Protocol / DPP)** testbed on **Linux (Ubuntu)**.  
It includes **scripts, notes, and screenshots** to demonstrate and replicate the process of implementing a DPP-based environment for secure device provisioning.

---

##  What is Wi-Fi Easy Connect / DPP?

Wi-Fi Easy Connect, also known as **DPP (Device Provisioning Protocol)**, is a secure and modern alternative to WPS. It enables device onboarding via QR codes, NFC, or other out-of-band methods – especially relevant for IoT and embedded environments.

---

## Important: Read Before You Start

Spec:  
https://www.wi-fi.org/system/files/Wi-Fi_Easy_Connect_Specification_v3.0.pdf

Source of used commands, what to look for at compiling wpa_supplicant and hostapd manually:  
https://android.googlesource.com/platform/external/wpa_supplicant_8/%2B/refs/tags/android-platform-11.0.0_r3/wpa_supplicant/README-DPP

---

## Before Setup
You must compile wpa_supplicant and hostapd manually as per the linked guide  
Check that your Wi-Fi interfaces support the following modes:  
- P2P
- Managed
- AP

---

## Tested Hardware
Intel NUCs (2018)  
ALFA AWUS036AXML Wi-Fi adapters  
Raspberry Pi Zero 2 W (needs wifi adapter)  
Raspberry Pi 5 (needs wifi adapter)  

---

## Scenario 1
Scenario 1 is using current available IoT Devices and their implementation of the provisioning proccess  

---
## Scenario 2
Scenario 2 Describes the case, That there are 3 Devices involved:  
Acces Point (NUC1: Interface wlx...), Configurator (NUC1: Interface wlp...), STA (Raspy)  
It is meant to demonstrate how DPP can work within a Smart Home environment and your Smartphone being the configurator. Since there are currently no implementations for Android/iOS we are simulating the mobile configurator. The actual QR Code reader is hosted on a public website and the NUC is pulling the Bootstrapping Keys from there and utilizes wpa?supplicant to configure AP and STAs.  

---
## Scenario 3
Scenario 3 describes the case that there are 2 Devices involved:  
Acces Point that is also the Configurator (NUC1), STA (Raspy)  
The Accesspoint also hosts a http server with a script where you can upload the bootstrapping keys, simulating a future cloud service to be able to submit Bootstrapping keys from anywhere.  
Note:  
Hostapd seems to have issues handling the AP services and DPP Configuration at the same time. Therefore we had to fall back to a similar version of the scripts we use in Scenario 2...  

---

## Upcoming
- Usability Study of the testbed
