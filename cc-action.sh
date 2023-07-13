#!/usr/bin/env bash

set -xeuo pipefail
IFS=$'\n\t'

file=~/Private/passwords/aws

printHelp () {
cat <<EOF
$0 <1-4|IP> [-p password] [-f file] [-db | -nodb | component-to-log] [-t num] [user] 

If password is given (before or after user), store it in file.

-db   Log to vaionmgmt
-nodb Log to postgres

component Log this component. No default.
-t        Log number of lines (default 100).

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
			if [[ -z "$which" ]]; then
				which="$1"
			elif [[ "$whatToDo" = log ]]; then
				component="$1"
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
	which=1
fi
if [[ -z "$user" ]]; then
	user=admin
fi

function constructPasswordLine {
	whichAWS=$1
	echo "^$whichAWS:.*"
}

function extractPasswordFromLine {
	line="$1"
	echo "$line" | sed 's/^\([0-9]\|.\)\+://'
}

if [[ ! -z "$password" ]]; then
	if grep -q "$(constructPasswordLine $which)" $file; then
		sed -i "s/$(constructPasswordLine $which)$/$which:$password/" $file
		echo Stored new password: $(grep $(constructPasswordLine $which) $file)
	else
		echo "$which:$password" >> $file
		echo Inserted new password $password for $which
	fi
fi

usePassword=`extractPasswordFromLine "$(grep $(constructPasswordLine $which) $file)"`
echo "using password '$usePassword'"

# If using AWS, only the number is given. Translate it to a URL.
# If whole IP is given, do nothing.
if [[ "$which" =~ ^[0-9]$ ]]; then
	which=aws-itest-0$which.aws.vaion.com
fi

echo "Using URL $which"


if [[ ! -z "$usePassword" ]] && [[ $forceNoPassword = false ]]; then
	case $whatToDo in
		db)
			sshpass -p $usePassword ssh "$user@$which" "shell -c \"docker-compose exec db psql -U postgres -d vaionmgmt\""
			;;
		nodb)
			sshpass -p $usePassword ssh "$user@$which" "shell -c \"docker-compose exec db psql -U postgres\""
			;;
		log)
			sshpass -p $usePassword ssh "$user@$which" "logs -f -t ${lines:-100} $component"
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