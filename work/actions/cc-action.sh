#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

printHelp () {
cat <<EOF
$0 <node-name> [-db | -nodb | component-to-log [-ha] [-l] [-t num] [user] | -sh component | -v | --patch component | --reboot component | --detail ] [--debug]

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

--detail Only logs the cached details of a CC

--debug Turn on debugging.

By default, we try to map the output's IDs onto real names. use --no-map to disable this.
EOF
}

user=
nodeName=
whatToDo=log
port=5432
haMode=false
less=false
debug=
mapFile=
component=

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--debug)
			debug=--debug
			;;
		--detail)
			whatToDo=detail
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
		-h|--help)
			printHelp
			exit 0
			;;
		*)
			if [[ -z "$nodeName" ]]; then
				nodeName="$1"
			elif [[ $whatToDo = log && $1 =~ ^[0-9]+$ ]] && [[ ! -z $component ]]; then
				lines=$1
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

if [[ -z "$user" ]]; then
	user=admin
fi

if [[ $whatToDo = detail ]]; then
	nodeProperName=$(get-cc-spec.sh -c $nodeName --get-proper-name)
	vms=$(get-cc-spec.sh -c $nodeName --get-vms)
	echocolour "$nodeName:"
	echo "VMS: $vms"
	echo "Proper name: $nodeProperName"
	exit 0
fi

nodeIp=$(get-cc-spec.sh -c $nodeName --get-ip $debug)
password=$(get-cc-spec.sh -c $nodeName --get-password $debug)

if [[ -z $nodeIp || -z $password ]]; then
	echo "Failed to find CC specs: $nodeIp; $password" >&2
	exit 1
fi

[[ $whatToDo = sh ]] && [[ $component = platform ]] && whatToDo=vplat
[[ $whatToDo = reboot ]] && [[ -z ${component+x} ]] && component=platform

if [[ $whatToDo = log ]] && [[ $haMode = true ]]; then
	hawatch $nodeName $component -cc -t ${lines:-100}
	exit 0
fi

case $whatToDo in
	db)
		set -x
		sshpass -p $password ssh -o StrictHostKeyChecking=no -t "$user@$nodeIp" "shell -ic \"docker-compose exec -it db psql -U postgres -d vaionmgmt -p $port\""
		;;
	nodb)
		set -x
		sshpass -p $password ssh -o StrictHostKeyChecking=no -t "$user@$nodeIp" "shell -ic \"docker-compose exec db psql -U postgres -p $port\""
		;;
	log)
		vmsName=$(get-cc-spec.sh -c $nodeName --get-vms $debug)
		if [[ ! -z $vmsName ]] && [[ -z $mapFile ]]; then
			mapFile=${vmsName/.*/}
		fi

		f=-f
		[[ $less = true ]] && f=

		shellCmd="logs -t ${lines:-100} $f $component"

		if [[ $component = platform ]]; then
			shellCmd="shell -c \"tail -n ${lines:-100} $f /var/log/supervisor/platform.log\""
		fi
		
		cmd="sshpass -p $password ssh -o StrictHostKeyChecking=no \"$user@$nodeIp\" '$shellCmd'"

		if [[ ! -z $mapFile ]] && [[ $mapFile != none ]]; then
			cmd+=" | map-IDs.sh $mapFile"
		fi
		if [[ $less = true ]]; then
			cmd+=" | less -r -S"
		fi

		echocolour $cmd >&2
		eval $cmd
		;;
	sh)
		do=bash
		[[ $component = mgmt || $component = ha ]] && do=sh

		set -x
		sshpass -p $password ssh -o StrictHostKeyChecking=no -t "$user@$nodeIp" "shell -ic \"docker-compose exec -it $component $do\""
		;;
	patch)
		echo "cc-patch.sh $nodeIp $component -p $password"
		$UTILS_DIR/cc-patch.sh $nodeIp $component -p $password
		;;
	vplat)
		$UTILS_DIR/awssh $nodeIp -p $password
		;;
	reboot)
		if [[ $component = platform ]]; then
			set -x
			sshpass -p $password ssh -o StrictHostKeyChecking=no -t "$user@$nodeIp" "reboot"
		else
			set -x 
			sshpass -p $password ssh -o StrictHostKeyChecking=no -t "$user@$nodeIp" "shell -ic \"docker-compose restart $component\""
		fi
		;;
	*)
		echo "Error: unknown action $whatToDo"
		printHelp
		exit 1
		;;
esac