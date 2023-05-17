#!/bin/bash

set -euo pipefail

function show_help {
cat <<EOF
words_per_scene.sh [-h]
                   <num-of-scenes> [-n <words-per-scene>] [-d <directory>]

Show word count breakdown inside directory - display how many words per scene there are, and how many words we went over the limit in total.

-h,--help      Display this help.
-n <num>       How many words per scene should be the maximum.
-d <dir>       The directory whose files are being considered (recursively).
-e <extension> File extension of the files we want to count up (without leading dot).
-p             Print default values.

Defaults:
-n -> 2,000
-d -> directory of last default file edited in Emacs
-e -> .org
EOF
}

function is_number {
	re='^[0-9]+$'
	if [[ "$1" =~ $re ]]; then
		isNumber=true
	else
		isNumber=false
	fi
}

sceneLimit=2000
defaultExtension="org"
extension=$defaultExtension
defaultDirectory=$(cat ~/Documents/emacs/.write-current-chapter | sed 's;\(.*/\)[^/]*$;\1;')
directory=$defaultDirectory

function print_defaults {
	echo "Number of words per scene (-n): $sceneLimit"
	echo "Default directory (-d): $defaultDirectory"
	echo "Default file extension (-e): $defaultExtension"
}

while [[ "$#" -gt 0 ]]; do
	case $1 in
		-h|--help)
			show_help
			exit 0
			;;
		-n)
			sceneLimit=$2
			shift
			is_number $sceneLimit
			if [[ $isNumber = false ]]; then
				echo "scene limit (option -n) needs a number"
				show_help
				exit 1
			fi
			;;
		-d)
			directory=$2
			shift
			if ! [[ -d $directory ]]; then
				echo "Directory option (-d) needs a directory name"
				show_help
				exit 1
			fi
			;;
		-e)
			extension=$2
			shift
			;;
		-p)
			print_defaults
			exit 0
			;;
		*)
			scenes=$1
			is_number $scenes
			if [[ $isNumber = false ]]; then
				echo "number of scenes needs to be actual number"
				show_help
				exit 1
			fi
			;;
	esac
	shift
done

wordsTotal=`find "$directory" -name "*.$extension" | sed 's/.*/"&"/' | xargs wc -w | tail -n 1 | sed 's/^[ \t]*//' | cut -d' ' -f 1`
wordsPerScene=$(bc <<< "$wordsTotal / $scenes")
predictedWords=$(bc <<< "$sceneLimit * $scenes")
wordsDelta=$(bc <<< "$predictedWords - $wordsTotal")

echo "$wordsTotal words in total"
echo "$wordsPerScene words per scene"
if [[ "$wordsDelta" -ge 0 ]]; then
	echo "$wordsDelta words to spare"
else
	echo `echo $wordsDelta | cut -d '-' -f 2` words too many
fi