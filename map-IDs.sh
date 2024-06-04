#!/usr/bin/env bash

set -euo pipefail
IFS=''

CYAN='\033[0;36m'
NC='\033[0m'

# Load the cluster functions
source ~/shell/cluster

function printHelp {
	cat <<EOF
$(basename $1) VMS-name [--debug] [--reverse name]

Parse output from stdin and map strings in the VMS file to given replacements.

If the --reverse option is passed, instead print the UUID associated with the given name for the VMS.
EOF
}

mapDir=$MAPS
defaultNameMapFile=ha
mapFile=
debug=false
reverse=

while [[ $# -gt 0 ]]; do
	opt=$1
	shift

	case $opt in
		--debug)
			debug=true
			;;
		-h|--help)
			printHelp $0
			exit 0
			;;
		--reverse)
			reverse=true
			item=$1
			shift
			;;
		*)
			mapFile=$mapDir/$opt
			;;
	esac
done

if [[ $reverse = true ]]; then
	grep :$item$ $mapFile | cut -d':' -f 1
	exit 0
fi

declare -A mappings

if [[ -f $mapFile ]]; then
	while read line; do
		id=$(echo $line | cut -d ':' -f 1)
		name=$(echo $line | cut -d ':' -f 2)
		
		if [[ $id = Context ]]; then
			# This is a line which cached where the VMS lives. Ignore it.
			continue
		fi

		mappings[$id]=$name
	done < <(cat $mapFile)
fi

function applyMap {
	# print="${@//\"/\\\"}"
	print="${@//\'/\'\"\'\"\'}"
	cmd="echo '$print'"

	for id in ${!mappings[@]}; do
		name=${mappings[$id]}
		if [[ $debug = true ]]; then
			echo "Mapping $id onto $name"
		fi
		
		cmd+=" | sed -u ''/$id/s//"'`'"printf \"${CYAN}$name${NC}\""'`'"/g''"
	done
	eval $cmd
}

while read -r line; do
	applyMap "$line"
done