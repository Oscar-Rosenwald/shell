#!/usr/bin/env bash

set -euo pipefail

# CSV format:
# IP:name:cached_password:VMS_URL

function printHelp {
	cat <<EOF
$0 OPTIONS

By default, this gives you the password of the specified CC.

 --get-ip = get the ip instead.

SEARCH FOR THESE VALUES
-c|-cc|--cc|--cloud-connector <CC name or IP>
                         -ip  <ip>

STOP THESE VALUES
   -n|--cc-name <CC name>
  -p|--password <password>
-vms|--vms-name <VMS name>
     --store-ip <ip>

OTHER
               --no-cache = force querying the VMS for the password.
-f|--file <password file> = Specify password file. Default aws.
                -h|--help = Print help.
EOF
}

passwordFile=~/Private/passwords/aws
getCookieScript=~/shell/get_cookie.py

# What CC are we referring to?
CC= # select CC name
ip= # select this IP
cached=true # If false, ask the VMS for the password
getIP=false # If true, get the IP of the CC. If false, get the password."

# Special actions to do with the selected CC.
forcedPassword= # store this password
ccName= # store this name
vmsName= # store this VMS name
storeIp= # store this CC IP

while [[ $# -gt 0 ]]; do
	opt=$1
	shift

	case $opt in
		--get-ip)
			getIP=true
			;;
		-c|-cc|--cc|--cloud-connector)
			CC=$1
			shift
			;;
		-ip)
			ip=$1
			shift
			;;
		-p|--password)
			forcedPassword=$1
			shift
			;;
		-n|--cc-name)
			ccName=$1
			shift
			;;
		-vms|--vms-name)
			vmsName=$1
			shift
			;;
		--store-ip)
			storeIp=$1
			shift
			;;
		-f|--file)
			passwordFile=$1
			shift
			;;
		--no-cache)
			cached=false
			;;
		-h|--help)
			printHelp
			exit 0
			;;
		*)
			echo "Unrecognised option $opt"
			printHelp
			exit 1
			;;
	esac
done

# Get first line containing argument.
# 
# Args
#   - 1 = occurance to search for in the password file
function __findLine {
	grep $1 $passwordFile | head -n 1
}

# Find attribute (column) of a line matching argument.
#
# Args:
#   - 1 = occurance to search for in the password file
#   - 2 = column
function __findAttribute {
	__findLine $1 | cut -d: -f $2
}

function __getIP {
	__findAttribute $CC 1
}

function __getCCNameFromIP {
	__findAttribute $ip 2
}

function __getCachedPassword {
	__findAttribute $CC 3
}

function __getVMSName {
	__findAttribute $CC 4
}

# Amend line in the password file
#
# Args:
#   - 1 = IP of CC
#   - 2 = name of CC
#   - 3 = password
#   - 4 = VMS name
function __storeAttributes {
	sed -i "s/.*$2.*/$1:$2:$3:$4/" $passwordFile
}

ipv4_regex="\<([0-9]{1,3}\.){3}[0-9]{1,3}\>"

# Ensure the CC variable is filled with the name of the cloud connector as it
# appears in the password file.
if [[ -z $CC ]]; then
	if [[ -z $ip ]]; then
		echo "Give me a cloud connector name or an ip. I have neither"
		exit 1
	fi
	CC=$(__getCCNameFromIP)
	if [[ -z $CC ]]; then
		read -p "New CC name: " CC
		__storeAttributes $ip $CC $forcedPassword $vmsName
		return $forcedPassword
	fi
elif [[ " $CC " =~ $ipv4_regex ]]; then
	ip=$CC
	CC=$(__getCCNameFromIP)
fi

# Args:
#   - 1 = new password
function storePassword {
	IP=$(__getIP)
	VMS=$(__getVMSName)

	__storeAttributes $IP $CC $1 $VMS
}

# Args:
#   - 1 = new VMS name
function storeVmsName {
	IP=$(__getIP)
	password=$(__getCachedPassword)

	__storeAttributes $IP $CC $password $1
}

# Args:
#   - 1 = new CC name
function storeCCName {
	IP=$(__getIP)
	password=$(__getCachedPassword)
	VMS=$(__getVMSName)

	__storeAttributes $IP $1 $password $VMS
}

# Args:
#   - 1 = new IP
function storeIP {
	password=$(__getCachedPassword)
	VMS=$(__getVMSName)

	__storeAttributes $1 $CC $password $VMS
}

# Store new values if any are given.
if [[ ! -z $vmsName ]]; then
	storeVmsName $vmsName
fi
if [[ ! -z $ccName ]]; then
	storeCCName $ccName
fi
if [[ ! -z $storeIp ]]; then
	storeIP $storeIp
fi
if [[ ! -z $forcedPassword ]]; then
	storePassword $forcedPassword
	return $forcedPassword
fi

# Ask for prompt and return user input.
#
# Args:
#   - 1 = part of the prompt 
function __requestAttribute {
	read -p "Please enter $1: " attribute
	echo $attribute
}

# Gets the password for a cloud connector from the VMS of the CC. If the VMS
# isn't known, asks user for it.
function __getPasswordFromVMS {
	vms=$(__getVMSName)
	IP=$(__getIP)

	if [[ -z $vms ]]; then
		vms=$(__requestAttribute "VMS name (without https://, including .com)")
		storeVmsName $vms
	fi

	cookie=$(python3 $getCookieScript $vms)
	if [[ -z $cookie ]]; then
		echo "Cannot find the cookie. You must be logged in in your browser to VMS $vms"
		exit 1
	fi

	nodeId=$(curl --cookie va=$cookie -s https://$vms/api/v1/nodes 2>/tmp/.curl1.log| jq '.[] | select(.network_interfaces != null) | .network_interfaces | to_entries[] | select(.value != null and .value.current_ip==''"'$IP'"'') | .value.node_id' | sed 's/"//g')
	if [[ -z $nodeId ]]; then
		echo "VMS $vms doesn't seem to have a node matching ip $ip"
		exit 1
	fi

	password=$(curl --cookie va=$cookie https://$vms/api/v1/nodes/"$nodeId"/credentials 2>/tmp/.curl2.log | jq '.password' | sed 's/"//g')
	if [[ -z $password ]]; then
		echo "VMS $vms gave us no password for node $nodeId"
		exit 1
	fi

	echo $password
}

# Check if we should return the IP rather than the password.
if [[ $getIP = true ]]; then
	__getIP
	exit 0
fi

### 
### Returning password.
### 

if [[ $cached = true ]]; then
	cachedPassword=$(__getCachedPassword)
	if [[ ! -z $cachedPassword ]]; then
		echo $cachedPassword
		exit 0
	fi
	echo "No cached password found. Getting new one."
fi

actual=$(__getPasswordFromVMS)
if [[ -z $actual ]]; then
	echo "CC $CC (or ip $ip) have no password on VMS '"$(__getVMSName)"'"
	exit 1
fi

storePassword $actual
echo $actual