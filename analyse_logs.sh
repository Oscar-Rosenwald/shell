#!/usr/bin/env bash

set -euo pipefail

# Options for what to get
options=("restarts" "panics" "start" "end" "first" "current" "both" "full")
restarts=${options[0]}
panics=${options[1]}
start=${options[2]}
end=${options[3]}
firstVersion=${options[4]}
currentVersion=${options[5]}
bothVersions=${options[6]}
full=${options[7]}

show_help () {
	cat <<EOF
$0 [-f file name] [-w what to show] [-s|--simple]

Default file name is mgmt.txt in current directory.
What to show can be:
  - $restarts how many restarts there are
  - $panics how many panics
  - $start time of first log
  - $end time of last log
  - $firstVersion first version logged in file
  - $currentVersion last version logged in file
  - $bothVersions show first and last version logged in file
  - $full will show all the above

Version options will warn if there is only one version in the file.

Default is "how many restarts".

Option -s, when give, only returns the relevant numbers, and doens't print any more information.
EOF
}

# 1: the -w argument
check_valid_option () {
	option=$1
	if [[ ! " ${options[*]} " =~ " ${option} " ]]; then
		echo "Failed validation: Invalid option $option, want:"
		echo "${options[*]}"
		echo
		show_help
		exit 1
	fi
}

get_logs_start () {
	head -n1 "$file" | cut -d '+' -f 1 | sed -e 's/\(.*\) $/\1/'
}

get_logs_end () {
	tail -n1 "$file" | cut -d '+' -f 1 | sed -e 's/\(.*\) $/\1/'
}

get_first_version () {
	grep "Git Commit:" "$file" | head -n 1 | sed 's/.*Git Commit: //'
}

get_last_version () {
	grep "Git Commit:" "$file" | tail -n 1 | sed 's/.*Git Commit: //'
}

# 1: first or last?
get_version () {
	whichOne=$1

	first=`get_first_version`
	last=`get_last_version`

	if [[ $first = $last ]]; then
		echo "$first WARNING: First and last versions are the same."
	elif [[ $whichOne = first ]]; then
		echo $first
	elif [[ $whichOne = last ]]; then
		 echo $last
	else
		echo "Passed wrong 'which' field to get_version"
		exit 1
	fi
}

count_restarts () {
	grep -c Builder "$file"
}

count_panics () {
	grep -c "Crash reason: panic" $file
}

file=./mgmt.txt
what=$restarts
simple=false

# Parse values
while [[ "$#" -gt 0 ]]; do
	opt="$1"
	shift

	case "$opt" in
		-h|help|--help)
			show_help
			exit 1
			;;
		-f)
			file="$1"
			shift
			;;
		-w)
			what=$1
			check_valid_option $what
			shift
			;;
		-s|--simple)
			simple=true
			;;
		*)
			echo "Invalid option '$opt'"
			show_help
			exit 1
			;;
	esac
done

case $what in
	$restarts)
		if [[ $simple = true ]]; then
			count_restarts
		else
			echo `count_restarts` "restarts in file $file"
		fi
		;;
	$panics)
		if [[ $simple = true ]]; then
			count_panics
		else
			echo `count_panics` "panics in file $file"
		fi
		;;
	$start)
		if [[ $simple = true ]]; then
			get_logs_start
		else
			echo "File $file starts at" `get_logs_start`
		fi
		;;
	$end)
		if [[ $simple = true ]]; then
			get_logs_end
		else
			echo "File $file ends at" `get_logs_end`
		fi
		;;
	$firstVersion)
		if [[ $simple = true ]]; then
			get_verson first
		else
			echo "File $file starts on version" $(get_version "first")
		fi
		;;
	$currentVersion)
		if [[ $simple = true ]]; then
			get_version last
		else
			echo "File $file ends on version" $(get_version "last")
		fi
		;;
	$bothVersions)
		if [[ $simple = true ]]; then
			echo "Argument $bothVersions does not support a simple output"
		fi
		echo "File $file starts on version" $(get_version "first")
		echo "File $file ends on version" $(get_version "last")
		;;
	$full)
		if [[ $simple = true ]]; then
			echo "Argument $full does not support a simple output"
		fi
		echo "File $file starts at" "'"`get_logs_start`"'" "and ends at" "'"`get_logs_end`"'".
		echo "It has" `count_restarts` "restarts and" `count_panics` "panics."
		echo "Its first version is" $(get_first_version)" and the last is" $(get_last_version)
		if [[ $(get_first_version) = $(get_last_version) ]]; then
			echo "WARNING: Versions are the same"
		fi
		;;
	*)
		echo "Invalid option - THIS SHOULD NOT BE REACHED!"
		exit 1
		;;
esac