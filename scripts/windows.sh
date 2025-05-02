#!/usr/bin/env sh
# reboot-to-windows.sh

WINDOWS_BOOT_ID=$(efibootmgr | grep "Windows Boot Manager" | awk '{print $1}' | sed 's/Boot//;s/\*//')
sudo efibootmgr --bootnext "$WINDOWS_BOOT_ID" && sudo reboot
