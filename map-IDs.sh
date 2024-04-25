#!/usr/bin/env bash

set -euo pipefail
IFS=''

CYAN='\033[0;36m'
NC='\033[0m'

# Load the cluster_ functions
source ~/shell/cluster

function printHelp {
	cat <<EOF
$basename $0 VMS-name [--debug]

Parse output from stdin and map strings in the VMS file to given replacements.
EOF
}

mapDir=~/Private/mappings
defaultNameMapFile=ha
mapFile=
debug=false

while [[ $# -gt 0 ]]; do
	opt=$1
	shift

	case $opt in
		--debug)
			debug=true
			;;
		*)
			mapFile=$mapDir/$opt
			;;
	esac
done

declare -A mappings

if [[ -f $mapFile ]]; then
	while read line; do
		id=$(echo $line | cut -d ':' -f 1)
		name=$(echo $line | cut -d ':' -f 2)
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