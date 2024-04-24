#!/usr/bin/env bash

set -euo pipefail
IFT=$'\n\t'

pictureDir=~/Pictures/Wallpapers/current
probabilityFile=$pictureDir/probabilities
arguments="$*"
debugFile=/tmp/choose_lock_screen_debug

if [[ " $arguments " =~ --debug ]]; then
	truncate -s 0 $debugFile
fi

# file name -> probability of choosing it.
declare -A probabilities

debug () {
	if [[ " $arguments " =~ --debug ]]; then
		echo "$1" >> $debugFile
	fi
}

# Fill in custom probabilities if any exist
if [[ -f "$probabilityFile" ]]; then
	while read probability; do
		name=$(echo $probability | cut -d ':' -f 1)
		prob=$(echo $probability | cut -d ':' -f 2)
		debug "Setting probability $prob% of file $name"
		probabilities[$name]=$prob
	done < <(cat "$probabilityFile")
fi

# Fill in probabilities of the rest of the files (those not given custom
# probability)
normalFiles=0
for file in ./*png; do
	file=${file#\./}
	if [[ -z ${probabilities[$file]:-} ]]; then
		normalFiles=$((normalFiles+1))
	fi
done

probabilitySum=0
for prob in ${probabilities[@]}; do
	probabilitySum=$((probabilitySum+prob))
done

remainingProbabilities=$((100-probabilitySum))
debug "$remainingProbabilities% are remaining for $normalFiles files after applying custom probabilty."

if [[ $probabilitySum -ge 100 ]] || [[ $remainingProbabilities -lt $normalFiles ]]; then
	echo "We have invalid probabilities on our hands."
	echo "Probabilities:"
	for file in ${!probabilities[@]}; do
		echo "$file: ${probabilities[$file]}"
	done
	echo "Which adds up to $probabilitySum"
	echo "You also have $remainingProbabilities remaining per cent to distribute over $normalFiles files."
	exit 1
fi

normalProbabilities=$(echo "scale=2; $remainingProbabilities / $normalFiles" | bc)
debug "All non-custom files will have $normalProbabilities% chance to be selected"

for file in $pictureDir/*png; do
	file=${file#\./}
	if [[ -z ${probabilities[$file]:-} ]]; then
		debug "File $file will be stored with normal probability"
		probabilities[$file]=$normalProbabilities
	fi
done

# 1% - 100%
rand=$((1 + $RANDOM % 100))
debug "Choosing random number $rand"
newWallpaper=
probCounter=0

for file in ${!probabilities[@]}; do
	prob=${probabilities[$file]}
	probCounter=$(echo "scale=2; $prob + $probCounter" | bc -l)
	debug "File $file has quotient $probCounter, which needs to be >= $rand to select this file"

	if (( $(echo "scale=2; $probCounter >= $rand" | bc -l) )); then
		newWallpaper=$file
		break
	fi

done

if [[ -z $newWallpaper ]]; then
	echo "Did not find any wallpaper for random probability $rand"
	echo "Probability counter: $probCounter"
	echo "${probabilities[@]}"
	exit 1
fi

debug "We selected $newWallpaper file"
echo $(realpath $newWallpaper)
exec 3>&-
exit 0 # Exit here because I haven't implemented the screen detection yet.

# =======================================================================
# =======================================================================
# =======================================================================
# ================== THE FOLLOWING DOESN'T WORK YET =====================
# =======================================================================
# =======================================================================
# =======================================================================

# TODO unfinished until I find out how to name a screen. xrandr doesn't differentiate between my home and my work screens.

# Choose the background image with the correct dimensions depending on the screens

home=false
work=false
other=false

while read screenLine; do
	screen=$(echo "$screenLine" | cut -d' ' -f 1)
	resolution=$(echo "$screenLine" | cut -d' ' -f 3 | sed -e 's/\([^+]*\)\+.*/\1/')

	echo $screen: $resolution
	case $screen in
		eDP-1)
		# noop
		;;
		HDMI-1-0)
		;;
		*)
			other=true
			;;
	esac
done < <(xrandr | grep -w 'connected')
