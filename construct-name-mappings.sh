#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

vmsName=
context=
sourceFile=./cluster.txt

function printHelp {
	cat <<EOF
$(basename $0)
  -vms <vms_name> [-s|--source <file>]
  --context <context> 

Construct an ID-to-name mapping and store it in the target file named after the VMS. Default for a source file is $(realpath $sourceFile).

If --context is given, store that value for future reference. It is optional.
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
		--context)
			context=$1
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

[[ -z $vmsName ]] && echo "No VMS name given." && exit 1

targetFile=$MAPS/$vmsName

function storeContext {
	if [[ ! -f $targetFile ]] || ! grep -q "^Context:" $targetFile; then
		echo "Context:$context" >> $targetFile
	else
		sed -i "s/Context:.*/Context:$context/" $targetFile
	fi
}

if [[ -f $targetFile ]]; then
	if [[ ! -z $context ]]; then
		storeContext
		echo "Stored context $context. Nothing else to do, because the file already exists."
		exit 0
	else
		echo "Vms $vmsName already has a file. Manual intervention required."
		exit 1
	fi
fi

if [[ ! -z $context ]]; then
	storeContext
	echo "Stored context $context."
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

	if [[ "${SGNames[$name]:+empty}" ]]; then
		SGNames[$name]=true
		echo "$id:$name" >> $targetFile
	fi
done < <(sed -n "4,$((lineNumber_Cluster-2))p" $sourceFile)

while read CC; do
	name=$(deSpace $(echo $CC | cut -d'|' -f 6))
	id=$(deSpace $(echo $CC | cut -d'|' -f 5))
	echo "$id:$name" >> $targetFile
done < <(sed -n "4,$((lineNumber_Cluster-2))p" $sourceFile)
