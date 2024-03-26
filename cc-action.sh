#!/usr/bin/env bash

set -xeuo pipefail
IFS=$'\n\t'

file=~/Private/passwords/aws

printHelp () {
cat <<EOF
$0 <1-4|IP> [-p password] [-f file] [-db | -nodb | component-to-log | -sh component] [-t num] [user] 

If password is given (before or after user), store it in file.

-n Force password retrieval from the VMS

-db   [port]  Log to vaionmgmt (on port if given)
-nodb [port]  Log to postgres (on port if given)

component Log this component. No default.
-t        Log number of lines (default 100).

-sh <component> Log into component using bash

Defaults:
- file  = $file
- user  = admin
- which = 1
EOF
}

password=
forceNoPassword=false
user=
which=
whatToDo=log
port=5432
new=false # If true, get new password for the CC.

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		-p)
			password="$2"
			if [[ -z "$password" ]]; then
				forceNoPassword=true
			fi
			shift
			;;
		-f)
			file="$2"
			shift
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
			elif [[ "$whatToDo" = log ]] || [[ $whatToDo = sh ]]; then
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

if [[ -z "$which" ]]; then
	which=AWS1
fi
if [[ -z "$user" ]]; then
	user=admin
fi


if [[ ! -z $password ]]; then
	get_cc_spec.sh -c $which -p $password
fi

# Check if we're getting a new password
if [[ $new = true ]]; then
	new='--no-cache'
else
	new=
fi

which=$(get_cc_spec.sh --get-ip -c $which)
usePassword=$(get_cc_spec.sh -c $which $new)
echo "Using IP $which and password '$usePassword'"

if [[ ! -z "$usePassword" ]] && [[ $forceNoPassword = false ]]; then
	case $whatToDo in
		db)
			sshpass -p $usePassword ssh -t "$user@$which" "shell -ic \"docker-compose exec -it db psql -U postgres -d vaionmgmt -p $port\""
			;;
		nodb)
			sshpass -p $usePassword ssh -t "$user@$which" "shell -ic \"docker-compose exec db psql -U postgres -p $port\""
			;;
		log)
			sshpass -p $usePassword ssh "$user@$which" "logs -f -t ${lines:-100} $component"
			;;
		sh)
			do=bash
			if [[ $component = mgmt ]]; then
				do=sh
			fi

			sshpass -p $usePassword ssh -t "$user@$which" "shell -ic \"docker-compose exec -it $component $do\""
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