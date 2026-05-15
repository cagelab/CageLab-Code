#!/bin/bash

# Enable WoL on all Ethernet connections; preserve spaces in connection names
WOL_METHODS="phy,unicast,multicast,broadcast,arp,magic"

nmcli -t -f NAME connection show | while IFS= read -r conn; do
    [[ -z $conn ]] && continue
    type=$(nmcli -g connection.type connection show "$conn" 2>/dev/null)
    case "$type" in
        ethernet|802-3-ethernet)
            echo "=== Enabling WoL for: $conn"
            nmcli connection modify "$conn" 802-3-ethernet.wake-on-lan "$WOL_METHODS"
            setting=$(nmcli -g 802-3-ethernet.wake-on-lan connection show "$conn" 2>/dev/null)
            echo "    Current WoL mode: ${setting:-unknown}"
            nmcli connection up "$conn"
            ;;
        *)
            continue
            ;;
    esac
done

echo "WoL configuration completed"