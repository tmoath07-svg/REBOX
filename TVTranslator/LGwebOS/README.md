# REBOX TV LG webOS Receiver

A standalone, **experimental** webOS TV IPK, used with the free iOS REBOX TV app.

## Purpose

Connects to the local iOS subtitle server `http://PHONE_IP:8080/state` and displays Arabic subtitles with colors, size, vertical position and background opacity set from the iOS app. No cloud backend.

## HDMI overlay

The `appinfo.json` opts into `"transparent":true` and `"defaultWindowType":"overlay"`. This behavior is not a documented universal third-party LG webOS consumer TV API. Community projects have demonstrated HDMI overlays on specific TVs, but **not on all webOS TVs**. If a particular model switches away from HDMI or shows an opaque background, that is a compatibility issue requiring model-specific investigation. No claim is made that it is guaranteed.

## Installation / no computer

1. Build the IPK in GitHub Actions (`Build REBOX TV LG webOS Receiver`).
2. On the LG TV, install **Developer Mode** from LG Apps, sign into a developer LG account and enable Dev Mode. Open Key Server and note the TV IP and on-TV passphrase.
3. On a device with webOS CLI that can access the same LAN, configure the TV with `ares-setup-device` using port 9922, user `prisoner`, then `ares-novacom -d myTV --getkey`, and `ares-install -d myTV ./com.tmoath07.reboxtv.lg_0.1.0_all.ipk`. Follow the official LG developer documentation. A Linux VM running on an iPad **may** be used in place of a PC, if network connectivity/SSH is available.
4. Launch REBOX TV on iPhone/iPad and keep it foregrounded; note its local address. Launch REBOX TV LG on the television, enter the phone local HTTP URL. Send a demo caption and check whether it is actually visible while playing Xbox over HDMI.
5. If overlay works, pressing the LG remote OK/Enter while the receiver has focus shows settings; Back hides settings.

## Boundaries

This receiver is not an automatic game text recognizer. The iOS sender currently requires manually pasted text or a selected screenshot. Real-time game subtitle recognition remains a later module. Standard webOS app installations are not supported by simply opening an IPK file in the TV browser; developer connection and app installation are needed. The TV and iOS phone must share reachable local Wi-Fi. No port forwarding is required.
