#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

if [[ "${1:-}" == "-h" ]]; then
	echo "em <file>[:line][<ignored input>] [depth]"
	exit 0
fi

line=""
file="${1:-/home/lightningman/Private/bugs.org}"
depth="${2:-5}"

# To find the file if the name is ambiguous.
function getUnfoundFile() {
	local file=$1
	local  __resultvar=$2
	local result=""

	# Find any matches in the code.

	foundFiles=$(find . -maxdepth "$depth" -ipath "*$file")

	if [[ -z "$foundFiles" ]]; then
		echo "ahoj" > /dev/null	# Here so the last printed thing is nothing.
		# Noop
	elif [[ $(echo "$foundFiles" | wc -l) = 1 ]]; then
		result="$foundFiles"
	elif [[ $(echo "$foundFiles" | wc -l) -gt 0 ]]; then
		echo "FOUND MULTIPLE FILES. READ WHICH ONE TO LOAD?"
		select choice in $(echo "$foundFiles"); do
				result=$choice; break
		done
	fi
    eval $__resultvar="'$result'"
}

# Split argument into file and line
if [[ "$file" =~ .*:.* ]]; then
	temp=$(echo "$file" | cut -d ":" -f 1)
	line='+'"$(echo "$file" | cut -d ":" -f 2)"''
	file="$temp"
fi


# Get file if file name isn't unambiguous
if [[ ! -f "$file" && ! -d "$file" ]]; then
	getUnfoundFile "$file" res

	if [[ "$res" = "" ]]; then
		while true; do
			echo "File $file does not exist at depth $depth."
			read -p "o - Open anyway; i - Increase depth by 1; q - Quit and exit [o/i/q] " response 
			case $response in
				o)
					break 		# File stays the same as the argument gave it -> makes a new file, or it's a directory
					;;
				i)
					depth=$((depth + 1))
					echocolour "Calling em again with depth $depth"
					em "$1" $depth
					exit 0
					;;
				q)
					exit -1
					;;
				*)
					echo "Unknown response $response. Try again."
					;;
			esac
		done
	else 
		file="$res"
	fi
fi

# Open Emacs client with file (and line)
if [[ "$line" == "" ]]; then
	emacsclient --create-frame "$file" 1> /dev/null & 
else
	emacsclient --create-frame -q "$line" "$file" 1> /dev/null &
fi

# Switch to emacs window after it opens
sleep 0.5s # Needed because the popup message screws with Ubuntu focus
fileName=$(echo "$file" | rev | cut -d "/" -f 1 | rev)
id=$(wmctrl -l | grep "$fileName.*Emacs" | head -n 1 | cut -d' ' -f 1)

if [[ "$id" == "" ]]; then
	wmctrl -a Emacs
else
	wmctrl -a "$id" -i
fi
