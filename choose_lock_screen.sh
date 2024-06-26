#!/usr/bin/env bash

set -euo pipefail
IFT=$'\n\t'

# USAGE
#
# This script prints the full path to the PNG wallpaper file that is to be used
# by i3lock as the lock screen. It looks inside the directory which is pointed
# to from the Pictures/Wallpapers/current link.
#
# All wallpapers must be in the PNG format. All files not ending in .png are
# ignored.
#
# If no external screens are detected, the laptop's screen is turned on before
# the script exits.
#
#
# SCREEN RESOLUTION
#
# There should be three variations of the same wallpaper, each with a different
# suffix:
#
#  - _Base.png:     The laptop screen uses this.
#  - _Home.png:     The home screen uses this.
#  - _Uxbridge.png: The ultra-wide Uxbridge office screen uses this.
#  - _Victoria.png: The two-screen setup in the Victoria office uses this.
#
# Which variation is used depends on which screens are connected.
#
#
# PROBABILITIES
#
# The user can specify how likely each wallpaper is. To do this, create a
# 'probabilities' file in the 'current' directory of the following format:
#
# <base-wallpaper-name>:<probability>
#
# The base name is the name of the wallpaper without a suffix. E.g.
# Not_Andy_Uxbridge.png would have a Not_Andy base name.
#
# Probability is a number between 1 and 100. The custom probabilities must add
# to a number <= 100, or the script panics. Setting a probability of any
# wallpaper to 100 guarantees that wallpaper will be chosen.
#
# Remaining available wallpapers in the 'current' directory will be assigned
# equal probability that remains after the custom probabilities are subtracted
# from 100.
#
# The probabilities file MUST end in a newline.

pictureDir=~/Pictures/Wallpapers/current
probabilityFile=$pictureDir/probabilities
debugFile=/tmp/choose_lock_screen_debug

truncate -s 0 $debugFile
# file name -> probability of choosing it.
declare -A probabilities

debug () {
	echo "$1" >> $debugFile
}

# Figure out which variation of the background to use depending on which screens
# are being used.
#
# Args:
#   - 1 = base name of the picture.
function applyResolution() {
	base=$1
	debug "We've selected file with base name $base"

	home=false
	work=false
	other=false

	while read screenLine; do
		screen=$(echo "$screenLine" | cut -d' ' -f 1)
		resolution=$(echo "$screenLine" | cut -d' ' -f 3 | sed -e 's/\([^+]*\)\+.*/\1/')

		case $screen in
			eDP-1)
				debug "Detected default screen"
			# noop
			;;
			HDMI-1-0)
				debug "Detected HDMI-1-0 screen with resolution $resolution"
				if [[ $resolution = 3440x1440 ]]; then
					# This is the resolution of my Uxbridge screen.
					debug "That is my work screen"
					work=true
				else
					debug "That is my home screen"
					home=true
				fi
				;;
			*)
				# We assume that everything else comes from the Victoria office.
				debug "Detected screen $screen with resolution $resolution"
				other=true
				;;
		esac

	done < <(xrandr 2>>$debugFile | grep -w 'connected')

	suffix=Victoria

	if [[ $home = false && $work = false && $other = false ]]; then
		debug "Default screen is the only one available. Make it the primary."
		xrandr --output eDP-1 --primary --pos 0x0 --auto
		suffix=Base
	elif [[ $home = true ]]; then
		suffix=Home
	elif [[ $work = true ]]; then
		suffix=Uxbridge
	fi

	result=${base}_$suffix.png
	debug "File $result will be our new wallpaper."
	echo $pictureDir/$result
}

# Print base names of all available wallpapers. This strips all the
# resolution-specific suffixes. The printed results are all unique.
function iterateBaseFiles() {
	ls -1 $pictureDir/*.png | xargs -n1 basename | sed "s/_\(Base\|Home\|Victoria\|Uxbridge\).png//" | uniq
}

# Fill in custom probabilities if any exist
if [[ -f "$probabilityFile" ]]; then
	while read probability; do
		name=$(echo $probability | cut -d ':' -f 1)
		prob=$(echo $probability | cut -d ':' -f 2)
		debug "Setting probability $prob% of file $name"

		if [[ $prob == 100 ]]; then
			applyResolution $name
			exit 0
		fi

		probabilities[$name]=$prob
	done < <(cat "$probabilityFile")
fi

# Fill in probabilities of the rest of the files (those not given custom
# probability)
normalFiles=0
while read file; do
	if [[ -z ${probabilities[$file]:-} ]]; then
		normalFiles=$((normalFiles+1))
	fi
done < <(iterateBaseFiles)

probabilitySum=0
for prob in ${probabilities[@]}; do
	probabilitySum=$((probabilitySum+prob))
done

debug "Custom probabilities: ${probabilities[@]}"

if [[ $probabilitySum -lt 100 ]]; then
	remainingProbabilities=$((100-probabilitySum))
	debug "$remainingProbabilities% are remaining for $normalFiles files after applying custom probabilty."

	if [[ $probabilitySum -gt 100 ]] || [[ $remainingProbabilities -lt $normalFiles ]]; then
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

	while read file; do
		if [[ -z ${probabilities[$file]:-} ]]; then
			debug "File $file will be stored with normal probability"
			probabilities[$file]=$normalProbabilities
		fi
	done < <(iterateBaseFiles)
fi

# 1% - 100%
rand=$((1 + $RANDOM % 100))
debug "Choosing random number $rand"
newWallpaperBase=
probCounter=0

# Choose the new wallpaper base.
for file in ${!probabilities[@]}; do
	prob=${probabilities[$file]}
	probCounter=$(echo "scale=2; $prob + $probCounter" | bc -l)
	debug "File $file has quotient $probCounter, which needs to be >= $rand to select this file"

	if (( $(echo "scale=2; $probCounter >= $rand" | bc -l) )); then
		newWallpaperBase=$file
		break
	fi

done

if [[ -z $newWallpaperBase ]]; then
	echo "Did not find any wallpaper for random probability $rand"
	echo "Probability counter: $probCounter"
	echo "${probabilities[@]}"
	exit 1
fi

debug "We selected $newWallpaperBase file base"
applyResolution $newWallpaperBase
