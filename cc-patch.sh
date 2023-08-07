#!/usr/bin/env bash

set -xeuo pipefail
IFS=$'\n\t'

file=~/Private/passwords/aws

printHelp () {
cat <<EOF
$0 <1-4|ip> [component] [-p password] [-f file] [user]

If password is given, store it in file.

Defaults:
- file      = $file
- user      = admin
- component = mgmt
EOF
}

password=
forceNoPassword=false
user=
component=
which=

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
		-h|--help)
			printHelp
			exit 0
			;;
		*)
			if [[ -z "$which" ]]; then
				which="$1"
			elif [[ -z "$component" ]]; then
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

if [[ -z "$component" ]]; then
	component=mgmt
fi
if [[ -z "$user" ]]; then
	user=admin
fi

if grep -q "^.*$which.*:.*$" $file; then
	which=$(grep "^.*$which.*:.*$" $file | cut -f 1 -d ':')
fi

function constructPasswordLine {
	whichAWS=$1
	echo "^$whichAWS:.*:.*$"
}

function extractPasswordFromLine {
	line="$1"
	echo "$line" | cut -f 3 -d ':'
}

function extractNameFromLine {
	line=$1
	echo "$line" | cut -f 2 -d ':'
}

if [[ ! -z "$password" ]]; then
	if grep -q "$(constructPasswordLine $which)" $file; then
		name=$(extractNameFromLine "$(grep $(constructPasswordLine $which) $file)")
		if [[ $password = $name ]]; then
			password=$(extractPasswordFromLine "$(grep $(constructPasswordLine $which) $file)")
		fi
		sed -ie "s/$(constructPasswordLine $which)/$which:$name:$password/" $file
		echo Stored new password: $(grep $(constructPasswordLine $which) $file)

	else
		read -p "Name: " name
		echo "$which:$name:$password" >> $file
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
	build-docker-component.sh $component

	file="/tmp/${component}_image.tgz"
	tag="bazel/go/vms/$component:${component}_image"

	sshpass -p $usePassword scp "$file" "$user@$which:/tmp/"
	sshpass -p $usePassword ssh "$user@$which" -C "shell -c \"export COMPOSE_PROJECT_NAME=default; docker-compose rm -f -s $component && docker load -i $file && rm $file && docker tag $tag $component:latest && docker-compose up -d $component\""
else
	update_component_docker.sh $which $component $user
fi