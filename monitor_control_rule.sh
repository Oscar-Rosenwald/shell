#!/bin/bash

# Get names of connected monitors
connectedMonitors=$(xrandr | grep -w connected | awk '{print $1}')

# Check number of connected monitors
numMonitors=$(echo "$connectedMonitors" | wc -l)

if [[ $numMonitors -gt 1 ]]; then
	xrandr --output $(echo "$connectedMonitors" | grep "eDP") --off
else
	xrandr --output $(echo "$connectedMonitors") --auto
fi