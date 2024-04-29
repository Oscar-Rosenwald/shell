#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

vmsName=
sourceFile=./cluster.txt

function printHelp {
	cat <<EOF
$(basename $0) -vms <vms_name> [-s|--source <file>]

Construct an ID-to-name mapping and store it in the target file named after the VMS. Default for a source file is $(realpath $sourceFile).
EOF
}

while [[ $# -gt 0 ]]; do
	opt=$1
	shift

	case $opt in
		-s|--source)
			sourceFile=$1
			;;
		-vms)
			vmsName=$1
			;;
		-h|--help)
			printHelp
			exit 0
			;;
		*)
			printHelp
			exit 1
			;;
	esac

	shift
done

[[ -z $vmsName ]] && echo "No target file given." && exit 1

targetFile=$MAPS/$vmsName

if [[ -f $targetFile ]]; then
	echo "Vms $vmsName already has a file. Manual intervention required"
	exit 1
fi

function deSpace {
	arg=$1
	arg="${arg#"${arg%%[![:space:]]*}"}"
	arg="${arg%"${arg##*[![:space:]]}"}"
	arg="${arg// /_}"
	echo $arg
}

lineNumber_Cluster=$(grep -n "^Cluster$" $sourceFile | head -n 1 | cut -d ':' -f 1)
declare -A SGNames

while read SG; do
	name=$(deSpace $(echo $SG | cut -d'|' -f 3))
	id=$(deSpace $(echo $SG | cut -d'|' -f 2))

	if [[ -z "${SGNames[$name]:-}" ]]; then
		SGNames[$name]=true
		echo "$id:$name" >> $targetFile
	fi
done < <(sed -n "4,$((lineNumber_Cluster-2))p" $sourceFile)

while read CC; do
	name=$(deSpace $(echo $CC | cut -d'|' -f 6))
	id=$(deSpace $(echo $CC | cut -d'|' -f 5))
	echo "$id:$name" >> $targetFile
done < <(sed -n "4,$((lineNumber_Cluster-2))p" $sourceFile)
