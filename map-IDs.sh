#!/usr/bin/env bash

set -euo pipefail
IFS=''

CYAN=$'\033[0;36m'
NC=$'\033[0m'

# Load the cluster functions
source $SHELL_DIR/cluster

function printHelp {
	cat <<EOF
$(basename $1) VMS-name [--debug] [--reverse name | --lookup id]

Parse output from stdin and map strings in the VMS file to given replacements.

If the --reverse option is passed, instead print the UUID associated with the given name for the VMS.
EOF
}

mapDir=$MAPS
defaultNameMapFile=ha
mapFile=
debug=false
reverse=
idOpt=

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
		--lookup)
			idOpt=$1
			shift
			;;
		*)
			mapFile=$mapDir/$opt
			;;
	esac
done

if [[ ! -z ${MAP_DEBUG:-} ]]; then
	debug=true
fi
if [[ $reverse = true ]]; then
	grep :$item$ $mapFile | cut -d':' -f 1 | sed 's/# //g'
	exit 0	
elif [[ ! -z $idOpt ]]; then
	grep $idOpt.*: $mapFile | cut -d':' -f 2 | sed 's/# //g'
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

		if [[ $line =~ ^#.* ]]; then
			continue
		fi

		mappings[$id]=$name
	done < <(cat $mapFile)
fi

sedCommand=
for id in ${!mappings[@]}; do
	name=${mappings[$id]}
	if [[ $debug = true ]]; then
		echo "Mapping $id onto $name"
	fi

	escapedName=$(echo "$name" | sed 's/[&/\]/\\&/g')
	sedCommand+="s/$id/${CYAN}${escapedName}${NC}/g;"
done

while read -r line; do
	line="${line//\'/\'\"\'\"\'}"
	[[ $debug = true ]] && set -x
	sed -u -e "${sedCommand%;}"
	set +x
done