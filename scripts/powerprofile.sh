#!/bin/sh

# Get the current profile
current_profile=$(powerprofilesctl get)

if [[ "$1" == "toggle" ]]; then
    # Toggle between profiles in order: balanced -> performance -> power-saver
    case "$current_profile" in
    balanced)
        powerprofilesctl set performance
        ;;
    performance)
        powerprofilesctl set power-saver
        ;;
    power-saver)
        powerprofilesctl set balanced
        ;;
    esac
    # Sleep a moment to let the profile switch
    sleep 0.2
    current_profile=$(powerprofilesctl get)
fi

# Output the current profile for Waybar
echo "${current_profile}"
