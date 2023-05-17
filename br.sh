#!/bin/bash

brightness="${1:-0.5}"
out="${2:-HDMI-1}"

cond1=$(echo "$brightness >= 0" | bc -l)
cond2=$(echo "$brightness <= 10" | bc -l)
echo $brightness
if [[ "$brightness" =~ ^[0-9]{1}$ ]]; then
	xrandr --output $out --brightness 0.$brightness
elif [[ "$brightness" =~ ^[0-9]{2}$ ]]; then # It's 10
	xrandr --output $out --brightness 1
else
	echo "Wrong arguments!"
fi