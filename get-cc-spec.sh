#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

export PID=$$

function printHelp() {
	cat <<EOF
$(basename $0) OPTIONS

Get or store information about a cloud connector.

GETTING INFO
--get-ip            gets the CC's IP
--get-name          gets the CC's internal name, AKA the name to use in the terminal
--get-proper-name   gets the actual name of the cloud connector
--get-vms           gets the VMS's URL
--get-password      gets the curreht SSH password for the cloud connector

STORING INFO
--new               requests all information not passed as an argument to create a new cached CC entry.
--store-name        stores/updates the internal name of the CC
--store-proper-name stores/updates the actual name of the CC
--store-vms         stores/updates the URL of the VMS. Do not include https://, but do include .com

IDENTIFYING THE CLOUD CONNECTOR
-c|--cloud-connector    internal name of the CC
--proper-name           real name of the CC
--vms                   name (not URL) of the VMS

OTHER
-h|--help   print this help
--debug     print debugging information

===========================
===========================
========= EXAMPLES ========
===========================
===========================

# NEW CC
$(basename $0) --new [--store-vms <vms> | --store-name <name> | --store-proper-name <proper-name> ]

# UPDATE CC'S NAME
$(basename $0) -c <old-name> --store-name <new-name>

# GET PASSWORD
$(basename $0) [ -c <name> | --proper-name <name> ] --get-password
EOF
}

# :name:proper_name:vms_url:
ccFile=$CCs
ccOrIp=
# What to do:
#
# - get IP
# - get CC internal name
# - get CC proper name
# - get CC password
# - get VMS of CC
# - store IP
# - store VMS
# - store proper name
# - add new CC
whatToDo= 

ccName=
vmsName=
properName=

storeCCName=
storeVmsName=
storeProperName=

debug=false

while [[ $# -gt 0 ]]; do
	opt=$1
	shift

	case $opt in
		--debug)
			debug=true
			;;
		
		# Storing value
		--new)
			whatToDo=new
			;;
		--store-name)
			[[ -z $whatToDo ]] && whatToDo=store-name
			storeCCName=$1
			shift
			;;
		--store-proper-name)
			[[ -z $whatToDo ]] && whatToDo=store-proper
			storeProperName=$1
			shift
			;;
		--store-vms)
			[[ -z $whatToDo ]] && whatToDo=store-vms
			storeVmsName=$1
			shift
			;;

		# Getting values
		--get-ip)
			whatToDo=ip
			;;
		--get-name)
			whatToDo=name
			;;
		--get-proper-name)
			whatToDo=properName
			;;
		--get-vms)
			whatToDo=vms
			;;
		--get-password)
			whatToDo=password
			;;

		# Parameters
		--vms)
			vmsName=$1
			shift
			;;
		--proper-name)
			properName=$1
			shift
			;;
		-c|--c|-cc|--cc|--cloud-connector)
			ccName=$1
			shift
			;;

		# Others
		-h|--help)
			printHelp
			;;
		*)
			echo "Unrecognised option $opt" >&2
			printHelp
			exit 1
			;;
	esac
done

if [[ $debug = true ]]; then
	set -x
fi

# If not told what to do, print all known information.
if [[ -z $whatToDo ]]; then
	whatToDo=all
fi

# Value types
nameIndex="nameIndex"
properIndex="properNameIndex"
vmsIndex="vmsIndex"

# =====================
# = Utility functions =
# =====================

# Args:
#   - 1 = name
#   - 2 = proper name
#   - 3 = vms name
function __constructLine {
	if [[ -z ${1:-} || -z ${2:-} || -z ${3:-} ]]; then
		echo "Not all arguments were given" >&2
		exit 1
	fi
	echo ":$1:$2:$3:"
}

# Args:
#   - 1 = current name
#   - 2 = current proper name (name on the VMS)
#   - 3 = current vms URL
#
#   - 4 = new value
#   - 5 = value index
function __store {
	name="$1"
	proper="$2"
	vms="$3"

	newValue="$4"
	index=$5 # From the value types enum.

	case $index in
		$nameIndex)
			search=$(__constructLine '.*' $proper "$vms")
			name=$newValue
			;;
		$properIndex)
			search=$(__constructLine "$name" '.*' "$vms")
			proper=$newValue
			;;
		$vmsIndex)
			search=$(__constructLine "$name" "$proper" '.*')
			vms=$newValue
			;;
	esac

	if ! grep -q "$search" $ccFile; then
		echo "Trying to store $newValue as $index, but $search sees no such CC in the file" >&2
		exit 1
	fi

	sed -i "s/$search/$(__constructLine "$name" "$proper" "$vms")/" $ccFile
}

# Args:
#   - 1 = known value
#   - 2 = known value index
#   - 3 = what to search for (enum index)
function __findAttribute {
	key=$1
	keyIndex=$2
	searchIndex=$3

	case $keyIndex in
		$nameIndex)
			search=$(__constructLine "$key" '.*' '.*')
			;;
		$properIndex)
			search=$(__constructLine '.*' "$key" '.*')
			;;
		*)
			echo "Invalid search key index $keyIndex" >&2
			exit 1
			;;
	esac

	if ! grep -q "$search" $ccFile; then
		echo "No known CC with cached line $search" >&2
		exit 1
	elif [[ $(grep -q "$search" $ccFile | wc -l) -gt 1 ]]; then
		echo "Too many results for line $search" >&2
		exit 1
	fi

	case $searchIndex in
		$nameIndex)
			index=2
			;;
		$properIndex)
			index=3
			;;
		$vmsIndex)
			index=4
			;;
	esac

	found=$(grep "$search" $ccFile | cut -d ':' -f $index)
	if [[ -z $found ]]; then
		echo "Failed to find $searchIndex with $key as $keyIndex (search string: $search)" >&2
		exit 1
	fi

	echo $found
}

# Fills ccName, properName, and vmsName based on which arguments were passed to
# it. At least 1 or 2 must not be empty. No arguments are optional, so if you
# don't know any, pass ''.
# 
# Args:
#   - 1 = name
#   - 2 = proper name
function __fillAll {
	name=$1
	proper=$2

	if [[ ! -z $name ]]; then
		properName=$(__findAttribute $name $nameIndex $properIndex)
		vmsName=$(__findAttribute $name $nameIndex $vmsIndex)
	elif [[ ! -z $properName ]]; then
		ccName=$(__findAttribute $proper $properIndex $nameIndex)
		vmsName=$(__findAttribute $proper $properIndex $vmsIndex)
	fi
}

# Args:
#   - 1 = vms name
#   - 2 = proper name
function __getIp {
	vms=$1
	name=$2
	
	cookie=$(get-cookie $vms)
	curl --cookie va=$cookie -s https://$vms/api/v1/nodes 2>/tmp/.curl1.log |
		jq '.[] | select(.network_interfaces != null and .name == ''"'$name'"'') | .network_interfaces | to_entries[] | select(.value != null and .value.current_ip != "") | .value.current_ip' |
		head -n 1 |
		sed 's/"//g'
}

# Args:
#   - 1 = vms name
#   - 2 = proper name
function __getPassword {
	vms=$1
	name=$2

	cookie=$(get-cookie $vms)
	nodeId=$(curl --cookie va=$cookie -s https://$vms/api/v1/nodes 2>/tmp/.curl1.log |
				 jq '.[] | select(.name == ''"'$name'"'') | .id' |
				 head -n 1 |
				 sed 's/"//g')

	password=$(curl --cookie va=$cookie https://$vms/api/v1/nodes/$nodeId/credentials 2>/tmp/.curl2.log |
				   jq '.password' |
				   sed 's/"//g')
	echo $password
}

# ==================
# = User functions =
# ==================

# Stores a completely new CC. All arguments are optional. Missing arguments will
# be prompted for.
#
# Args:
#   - 1 = name
#   - 2 = proper name
#   - 3 = vms name
storeNew() {
	name=$1
	proper=$2
	vms=$3
	
	if [[ -z $name ]]; then
		read -p "What will you call this new CC? " name
	fi
	if [[ -z $vms ]]; then
		read -p "What VMS is CC $name on? (no https://, include .com): " vms
	fi
	if [[ -z $proper ]]; then
		read -p "What does vms $vms call CC $name? " proper
	fi

	echo $(__constructLine $name $proper $vms) >> $ccFile
}

# Updates whichever of the three arguments is empty by prompting the user for
# the information.
#
# Args:
#   - 1 = known name
#   - 2 = known proper name
#   - 3 = vms name
update() {
	name=$1
	proper=$2
	vms=$3

	emptyNum=0
	for val in $name $proper $vms; do
		if [[ -z $val ]]; then
			emptyNum=$((emptyNum+1))
		fi
	done

	if [[ $emptyNum != 1 ]]; then
		echo "Cannot update - too many or too few unknown arguments (looking for 1): $(__constructLine ${name:-'<missing>'} ${proper:-'<missing>'} ${vms:-'<missing>'})" >&2
		exit 1
	fi

	if [[ -z $name ]]; then
		name=$(__findAttribute $proper $properIndex $nameIndex)
		read -p "What will you call CC $proper on VMS $vms? " newName
		__store $name $proper $vms $newName $nameIndex
	elif [[ -z $proper ]]; then
		proper=$(__findAttribute $name $nameIndex $properIndex)
		read -p "What is CC $proper called on VMS ($vms)? " newProper
		__store $name $proper $vms $newProper $properIndex
	else
		vms=$(__findAttribute $name $nameIndex $vmsIndex)
		read -p "What is CC $name's VMS called? (no https://, include .com): " newVms
		__store $name $proper $vms $newVms $vmsIndex
	fi
}

findName() {
	__findAttribute $properName $properIndex $nameIndex
}

findProperName() {
	__findAttribute $ccName $nameIndex $properIndex
}

findVmsName() {
	if [[ ! -z $ccName ]]; then
		value=$ccName
		index=$nameIndex
	elif [[ ! -z $properName ]]; then
		value=$properName
		index=$properIndex
	fi

	__findAttribute $value $index $vmsIndex
}

if [[ $debug = true ]]; then
	echo "Do: $whatToDo, name: $ccName, proper name: $properName, vms name: $vmsName" >&2
fi

case "$whatToDo" in
	# Store
	new)
		storeNew "$ccName" "$properName" "$vmsName"
		;;
	store-vms)
		__fillAll "$ccName" "$properName"
		__store "$ccName" "$properName" "$vmsName" "$storeVmsName" "$vmsIndex"
		;;
	store-name)
		__fillAll "$ccName" "$properName"
		__store "$ccName" "$properName" "$vmsName" "$storeCCName" "$nameIndex"
		;;
	store-proper)
		__fillAll "$ccName" "$properName"
		__store "$ccName" "$properName" "$vmsName" "$storeProperName" "$properIndex"
		;;

	# Get
	ip)
		__fillAll "$ccName" "$properName"
		__getIp "$vmsName" "$properName"
		;;
	name)
		findName
		;;
	properName)
		findProperName
		;;
	vms)
		findVmsName
		;;
	password)
		__fillAll "$ccName" "$properName"
		__getPassword "$vmsName" "$properName"
		;;
	all)
		if [[ ! -z $ccName ]]; then
			value=$ccName
			index=$nameIndex
		elif [[ ! -z $vmsName ]]; then
			value=$vmsName
			index=$vmsIndex
		elif [[ ! -z $properName ]]; then
			value=$properName
			index=$properIndex
		fi

		search=$(__constructLine "${ccName:-.*}" "${properName:-.*}" "${vmsName:-.*}")
		line=$(grep $search $ccFile)

		index=2
		for name in "Cached name" "Actual name" "VMS name"; do
			l=$(echo $line | cut -d ':' -f $index)
			echo "$name: $l"
			index=$((index+1))
		done
		;;
	*)
		echo "Don't know what to do with '$whatToDo'" >&2
		exit 1
		;;
esac