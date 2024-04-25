#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

printHelp () {
cat <<EOF
$0 <1-4|IP> [-p password] [-db | -nodb | component-to-log [-ha] [-l] [-t num] [user] | -sh component | -v | --patch component | --reboot component ] [--debug]

If password is given (before or after user), store it in the password file.

-n Force password retrieval from the VMS

-db   [port]  Log to vaionmgmt (on port if given)
-nodb [port]  Log to postgres (on port if given)

component Log this component. No default.
-t        Log number of lines (default 100).
-ha       Show only lines relevant for high availability.
-l        Don't follow the log. Show in a 'less' style.

-sh <component> Log into component using bash.
-v              Enter vplat.

--patch  <component> Patch this component.
--reboot <component> Reboot the component. "platform" or "" reboots the whole node.

--debug Turn on debugging.

By default, we try to map the output's IDs onto real names. use --no-map to disable this.
EOF
}

password=
forceNoPassword=false
user=
which=
whatToDo=log
port=5432
new=false # If true, get new password for the CC.
haMode=false
less=false
debug=
mapFile=

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		-p)
			password="$2"
			if [[ -z "$password" ]]; then
				forceNoPassword=true
			fi
			shift
			;;
		--debug)
			debug=--debug
			;;
		-ha)
			haMode=true
			;;
		-l)
			less=true
			;;
		-db)
			whatToDo=db
			;;
		-nodb)
			whatToDo=nodb
			;;
		-sh)
			whatToDo=sh
			;;
		-v)
			whatToDo=vplat
			;;
		--patch)
			whatToDo=patch
			;;
		--reboot)
			whatToDo=reboot
			;;
		--no-map)
			mapFile=none
			;;
		-t)
			if [[ ! $whatToDo = log ]]; then
				echo "-t is only valid if action is log. Action is $whatToDo"
				printHelp
				exit 1
			fi
			lines=$2
			shift
			;;
		-n)
			new=true
			;;
		-h|--help)
			printHelp
			exit 0
			;;
		*)
			if [[ -z "$which" ]]; then
				which="$1"
			elif [[ "$whatToDo" = log ]] || [[ $whatToDo = sh ]] || [[ $whatToDo = patch ]] || [[ $whatToDo = reboot ]]; then
				component="$1"
			elif ([[ $whatToDo = db ]] || [[ $whatToDo = nodb ]]) && [[ $1 =~ ^[0-9]+$ ]]; then
				port=$1
			elif [[ -z "$user" ]]; then
				user="$1"
			else
				printHelp
				exit 1
			fi
			;;
	esac
	shift
done

if [[ ! -z $debug ]]; then
	set -x
fi

if [[ -z "$which" ]]; then
	which=AWS1
fi
if [[ -z "$user" ]]; then
	user=admin
fi


if [[ ! -z $password ]]; then
	get_cc_spec.sh -c $which -p $password $debug
fi

# Check if we're getting a new password
if [[ $new = true ]]; then
	new='--no-cache'
else
	new=
fi

which=$(get_cc_spec.sh --get-ip -c $which $debug)
usePassword=$(get_cc_spec.sh -c $which $new $debug)
echo "Using IP $which and password '$usePassword'"

[[ $whatToDo = sh ]] && [[ $component = platform ]] && whatToDo=vplat
[[ $whatToDo = reboot ]] && [[ -z ${component+x} ]] && component=platform

if [[ $whatToDo = log ]] && [[ $haMode = true ]]; then
	hawatch $which $component -cc -t ${lines:-100}
	exit 0
fi

if [[ ! -z "$usePassword" ]] && [[ $forceNoPassword = false ]]; then
	case $whatToDo in
		db)
			set -x
			sshpass -p $usePassword ssh -o StrictHostKeyChecking=no -t "$user@$which" "shell -ic \"docker-compose exec -it db psql -U postgres -d vaionmgmt -p $port\""
			;;
		nodb)
			set -x
			sshpass -p $usePassword ssh -o StrictHostKeyChecking=no -t "$user@$which" "shell -ic \"docker-compose exec db psql -U postgres -p $port\""
			;;
		log)
			vmsName=$(get_cc_spec.sh -c "$which" --get-vms $debug)
			if [[ ! -z $vmsName ]] && [[ -z $mapFile ]]; then
				mapFile=$vmsName
			fi

			shellCmd="logs -t ${lines:-100} -f $component"

			if [[ $component = platform ]]; then
				shellCmd="shell -c \"tail -n ${lines:-100} /var/lob/supervisor/platform.log\""
			fi
			
			cmd="sshpass -p $usePassword ssh -o StrictHostKeyChecking=no \"$user@$which\" '$shellCmd'"

			if [[ ! -z $mapFile ]]; then
				cmd+=" | map-IDs.sh $mapFile"
			fi
			if [[ $less = true ]]; then
				cmd+=" | less"
			fi

			echocolour $cmd
			eval $cmd
			;;
		sh)
			do=bash
			[[ $component = mgmt ]] && do=sh

			set -x
			sshpass -p $usePassword ssh -o StrictHostKeyChecking=no -t "$user@$which" "shell -ic \"docker-compose exec -it $component $do\""
			;;
		patch)
			cc-patch.sh $which $component
			;;
		vplat)
			awssh $which -p $usePassword
			;;
		reboot)
			if [[ $component = platform ]]; then
				set -x
				sshpass -p $usePassword ssh -o StrictHostKeyChecking=no -t "$user@$which" "reboot"
			else
				set -x 
				sshpass -p $usePassword ssh -o StrictHostKeyChecking=no -t "$user@$which" "shell -ic \"docker-compose restart $component\""
			fi
			;;
		*)
			echo "Error: unknown action $whatToDo"
			printHelp
			exit 1
			;;
	esac
else
	echo "Action $whatToDo cannot be performed without a password"

fi